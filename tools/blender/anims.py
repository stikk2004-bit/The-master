"""Procedural animation for the shared 22-bone skeleton.

Rotations are given about the armature's own axes (X across, Y back, Z up) and converted
into each bone's frame, so "rx < 0" always means "swing forward" for a hanging limb and
"lean forward" for the spine. Legs are placed with a two-bone IK solver so feet land and
stay put instead of sliding.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 24


def _qworld(rx=0.0, ry=0.0, rz=0.0):
    return (Quaternion((0, 0, 1), rz) @ Quaternion((0, 1, 0), ry) @ Quaternion((1, 0, 0), rx))


class Poser:
    def __init__(self, rig, k):
        self.rig = rig
        self.k = k
        self.rest = {pb.name: pb.bone.matrix_local.to_3x3() for pb in rig.pose.bones}
        self.head = {pb.name: pb.bone.head_local.copy() for pb in rig.pose.bones}
        self.tail = {pb.name: pb.bone.tail_local.copy() for pb in rig.pose.bones}

    def reset(self):
        for pb in self.rig.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()

    def rot(self, name, rx=0.0, ry=0.0, rz=0.0):
        M = self.rest[name]
        qw = _qworld(rx, ry, rz).to_matrix()
        self.rig.pose.bones[name].rotation_quaternion = (M.transposed() @ qw @ M).to_quaternion()

    def move(self, name, v):
        M = self.rest[name]
        self.rig.pose.bones[name].location = M.transposed() @ Vector(v)

    def key(self, frame):
        for pb in self.rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if pb.name in ("Hips", "Root"):
                pb.keyframe_insert("location", frame=frame)

    # ---------------------------------------------------------- leg IK
    def leg(self, side, hip_drop, ankle_fwd, ankle_up, foot_pitch=0.0, toe=0.0, spread=0.0):
        """Place the ankle ankle_fwd meters ahead of the hip (forward = -Y) and ankle_up above
        its rest height, with the hips lowered by hip_drop. Solves thigh and knee angles."""
        k = self.k
        hip = self.head["UpperLeg." + side]
        knee = self.head["LowerLeg." + side]
        ankle = self.head["Foot." + side]
        L1 = (knee - hip).length
        L2 = (ankle - knee).length
        hip_z = hip.z - hip_drop
        tz = ankle.z + ankle_up
        down = hip_z - tz
        fwd = ankle_fwd
        D = math.hypot(fwd, down)
        D = min(D, (L1 + L2) * 0.9995)
        D = max(D, abs(L1 - L2) + 1e-4)
        cos_k = (L1 * L1 + L2 * L2 - D * D) / (2 * L1 * L2)
        bend = math.pi - math.acos(max(-1.0, min(1.0, cos_k)))
        a0 = math.atan2(fwd, down)
        cos_b = (L1 * L1 + D * D - L2 * L2) / (2 * L1 * D)
        beta = math.acos(max(-1.0, min(1.0, cos_b)))
        thigh = a0 + beta           # forward swing of the thigh from straight down
        self.rot("UpperLeg." + side, rx=-thigh, ry=0.0, rz=0.0)
        if spread:
            self.rot("UpperLeg." + side, rx=-thigh, ry=spread * (1 if side == "L" else -1))
        self.rot("LowerLeg." + side, rx=bend)
        # keep the sole level, then add the roll of the step
        self.rot("Foot." + side, rx=(thigh - bend) + foot_pitch)
        self.rot("Toe." + side, rx=toe)


def _clear(rig):
    rig.animation_data_create()
    rig.animation_data.action = None


def _begin(rig, name):
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    return act


def _finish(rig, act, track, frames, cyclic=True):
    if cyclic:
        for fc in _fcurves(act):
            m = fc.modifiers.new("CYCLES")
    tr = rig.animation_data.nla_tracks.new()
    tr.name = track
    st = tr.strips.new(track, 1, act)
    st.action_frame_start = 1
    st.action_frame_end = frames + 1
    rig.animation_data.action = None


def _fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
        return out


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ gait
def gait(P, p, stance, a, lift, heel_lift=0.05, toe_off=0.5, strike=-0.25):
    """Ankle path for one foot at cycle fraction p. Returns (fwd, up, foot_pitch, toe)."""
    p %= 1.0
    if p < stance:
        s = p / stance
        fwd = a - 2 * a * s
        hl = smooth((s - 0.72) / 0.28)
        up = heel_lift * hl
        pitch = strike * (1 - smooth(s / 0.14)) + toe_off * hl
        toe = -pitch * hl
        return fwd, up, pitch, toe
    s = (p - stance) / (1 - stance)
    fwd = -a + 2 * a * smooth(s)
    up = lift * math.sin(math.pi * s) ** 0.9 + heel_lift * (1 - smooth(s / 0.3))
    pitch = toe_off * (1 - smooth(s / 0.35)) + strike * smooth((s - 0.65) / 0.35)
    return fwd, up, pitch, 0.0


def cycle(ps, name, P, stance, a, lift, hip_base, bob, lean, arm_swing, elbow, run=False, sneak=False, carry=False, lantern=False,
          v_ref=None, sway=0.035):
    """One looping step cycle. v_ref, if given, sets the cycle length so the planted foot moves at
    exactly v_ref meters a second: the game divides its walking speed by the same number, so feet
    never slide however fast or slow a man walks."""
    k = ps.k
    if v_ref:
        P = 2.0 * a * k / (stance * v_ref)
        # sink the hips just enough that the legs can reach both ends of the stride
        if not run and not sneak:
            need = 0.85 - math.sqrt(max(0.85 ** 2 - a ** 2, 0.01))
            hip_base = max(hip_base, need - bob + 0.008)
    frames = max(8, int(round(P * FPS)))
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    for f in range(frames + 1):
        p = f / frames
        ps.reset()
        w = 2 * math.pi * p
        drop = (hip_base + bob * math.cos(2 * w)) * k if not run else (hip_base - bob * math.cos(2 * w + 0.6)) * k
        ps.move("Hips", (0, 0, -drop))
        for side, off in (("L", 0.0), ("R", 0.5)):
            fwd, up, pitch, toe = gait(P, p + off, stance, a * k, lift * k, heel_lift=(0.02 if sneak else 0.05) * k,
                                       toe_off=0.3 if sneak else (0.7 if run else 0.5))
            ps.leg(side, drop, fwd, up, pitch, toe)
        yaw = 0.07 * math.cos(w) * (1.4 if run else 1.0)
        ps.rot("Hips", rx=lean * 0.3, rz=-yaw, ry=sway * math.sin(w))
        ps.rot("Spine", rx=lean * 0.5, rz=yaw * 0.6)
        ps.rot("Chest", rx=lean * 0.3 + (0.02 * math.sin(2 * w)), rz=yaw * 0.9)
        ps.rot("Neck", rx=-lean * 0.55)
        ps.rot("Head", rx=-lean * 0.35, rz=-yaw * 0.4)
        sw = arm_swing * math.cos(w)
        if carry:
            _carry_arm(ps, "L")
            ps.rot("UpperArm.R", rx=-sw * 0.6, ry=-0.15)
            ps.rot("LowerArm.R", rx=-elbow)
        elif lantern:
            ps.rot("UpperArm.R", rx=-0.75 + 0.05 * math.sin(w * 2), ry=0.1)
            ps.rot("LowerArm.R", rx=-0.55)
            ps.rot("UpperArm.L", rx=sw, ry=0.15)
            ps.rot("LowerArm.L", rx=-elbow)
        elif sneak:
            for s2, sg in (("L", 1), ("R", -1)):
                ps.rot("UpperArm." + s2, rx=-0.45 + sg * sw * 0.3, rz=0.0, ry=-0.12 * sg)
                ps.rot("LowerArm." + s2, rx=-1.0)
                ps.rot("Hand." + s2, rx=0.2)
        else:
            # held a little out from the body, so hands and cuffs clear the coat as they swing
            ps.rot("UpperArm.L", rx=sw, ry=0.15)
            ps.rot("UpperArm.R", rx=-sw, ry=-0.15)
            ps.rot("LowerArm.L", rx=-elbow - max(0.0, -sw) * 0.5)
            ps.rot("LowerArm.R", rx=-elbow - max(0.0, sw) * 0.5)
            ps.rot("Hand.L", rx=-0.1)
            ps.rot("Hand.R", rx=-0.1)
        ps.key(f + 1)
    _finish(rig, act, name, frames)


def _carry_arm(ps, side):
    # forearm level and forward, palm up under a tray
    sg = 1 if side == "L" else -1
    ps.rot("UpperArm." + side, rx=-0.25, ry=-0.12 * sg)
    ps.rot("LowerArm." + side, rx=-1.45, rz=0.25 * sg)
    ps.rot("Hand." + side, rx=0.0, ry=-1.2 * sg)


def idle(ps, name="Idle", seconds=3.0, sneak=False, carry=False, lantern=False, look=False):
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        ps.reset()
        breath = math.sin(w * 2)
        sway = math.sin(w)
        if sneak:
            drop = 0.3 * k
            ps.move("Hips", (0.0, 0, -drop))
            ps.leg("L", drop, -0.02 * k, 0.0, 0.0, 0.0, spread=0.05)
            ps.leg("R", drop, 0.18 * k, 0.0, 0.0, 0.0, spread=0.05)
            ps.rot("Hips", rx=0.35)
            ps.rot("Spine", rx=0.2 + 0.015 * breath)
            ps.rot("Chest", rx=0.1 + 0.02 * breath)
            ps.rot("Neck", rx=-0.4)
            ps.rot("Head", rx=-0.25, rz=0.25 * math.sin(w))
            for s2, sg in (("L", 1), ("R", -1)):
                ps.rot("UpperArm." + s2, rx=-0.5, ry=-0.12 * sg)
                ps.rot("LowerArm." + s2, rx=-1.05)
        else:
            drop = (0.012 + 0.004 * breath) * k
            ps.move("Hips", (0.012 * k * sway, 0, -drop))
            ps.leg("L", drop, -0.03 * k + 0.0, 0.0, 0.0, 0.0, spread=0.035)
            ps.leg("R", drop, 0.05 * k, 0.0, 0.0, 0.0, spread=0.03)
            ps.rot("Hips", ry=0.025 * sway)
            ps.rot("Spine", rx=0.01 * breath)
            ps.rot("Chest", rx=-0.02 + 0.025 * breath, ry=-0.015 * sway)
            if look:
                ps.rot("Neck", rz=0.5 * math.sin(w) * smooth(abs(math.sin(w)) * 1.5))
                ps.rot("Head", rz=0.35 * math.sin(w), rx=0.05)
            else:
                ps.rot("Head", rz=0.08 * math.sin(w * 0.5 + 1.0), rx=0.03 * breath)
            if carry:
                _carry_arm(ps, "L")
                ps.rot("UpperArm.R", rx=0.03, ry=-0.16)
                ps.rot("LowerArm.R", rx=-0.25)
            elif lantern:
                ps.rot("UpperArm.R", rx=-0.8, ry=0.1)
                ps.rot("LowerArm.R", rx=-0.5)
                ps.rot("UpperArm.L", rx=0.04, ry=0.17)
                ps.rot("LowerArm.L", rx=-0.25)
            else:
                ps.rot("UpperArm.L", rx=0.03 + 0.02 * breath, ry=0.17)
                ps.rot("UpperArm.R", rx=0.03 + 0.02 * breath, ry=-0.17)
                ps.rot("LowerArm.L", rx=-0.22)
                ps.rot("LowerArm.R", rx=-0.22)
                ps.rot("Hand.L", rx=-0.15)
                ps.rot("Hand.R", rx=-0.15)
        ps.key(f + 1)
    _finish(rig, act, name, frames)


def seated_legs(ps, drop):
    for side in ("L", "R"):
        ps.leg(side, drop, 0.46 * ps.k, 0.0, 0.0, 0.0, spread=0.06)


def sit(ps, name="Sit", talk=False, write=False, drink=False, seconds=4.0):
    """Seated in a chair whose seat is 0.46 m high, centered 0.05 m behind the origin."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        ps.reset()
        breath = math.sin(w * 2)
        drop = 0.46 * k - 0.0
        hip = ps.head["UpperLeg.L"]
        # hips settle back onto the seat
        ps.move("Hips", (0, 0.1 * k, -(hip.z - 0.5 * k)))
        for side in ("L", "R"):
            # thighs level, shins down to the floor
            L1 = (ps.head["LowerLeg." + side] - ps.head["UpperLeg." + side]).length
            ps.rot("UpperLeg." + side, rx=-math.pi / 2 + 0.05, ry=0.06 * (1 if side == "L" else -1))
            ps.rot("LowerLeg." + side, rx=math.pi / 2 - 0.1)
            ps.rot("Foot." + side, rx=0.05)
        lean = 0.0
        if write:
            lean = 0.32
        elif talk:
            lean = 0.08 + 0.05 * math.sin(w)
        ps.rot("Hips", rx=-0.05)
        ps.rot("Spine", rx=lean * 0.5 + 0.01 * breath)
        ps.rot("Chest", rx=lean * 0.4 + 0.02 * breath, rz=(0.12 * math.sin(w) if talk else 0.0))
        ps.rot("Neck", rx=-lean * 0.2)
        if talk:
            ps.rot("Head", rx=0.06 * math.sin(w * 3), rz=0.25 * math.sin(w + 0.5))
            ps.rot("UpperArm.R", rx=-0.55 - 0.2 * math.sin(w * 2), ry=-0.15)
            ps.rot("LowerArm.R", rx=-1.2 - 0.3 * math.sin(w * 3 + 1.0), rz=-0.2)
            ps.rot("Hand.R", rx=0.2 * math.sin(w * 4))
            ps.rot("UpperArm.L", rx=-0.35, ry=0.1)
            ps.rot("LowerArm.L", rx=-1.1)
        elif write:
            ps.rot("Head", rx=0.25)
            ps.rot("UpperArm.R", rx=-0.55, ry=-0.2)
            ps.rot("LowerArm.R", rx=-1.35 + 0.06 * math.sin(w * 8), rz=-0.35 + 0.1 * math.sin(w * 5))
            ps.rot("Hand.R", rx=0.35, rz=0.1 * math.sin(w * 11))
            ps.rot("UpperArm.L", rx=-0.5, ry=0.25)
            ps.rot("LowerArm.L", rx=-1.35, rz=0.4)
        elif drink:
            lift = smooth((math.sin(w) + 0.2) * 1.3)
            ps.rot("Head", rx=-0.12 * lift)
            ps.rot("UpperArm.R", rx=-0.4 - 0.5 * lift, ry=-0.15)
            ps.rot("LowerArm.R", rx=-1.2 - 0.9 * lift)
            ps.rot("UpperArm.L", rx=-0.35, ry=0.1)
            ps.rot("LowerArm.L", rx=-1.15)
        else:
            ps.rot("Head", rz=0.1 * math.sin(w * 0.5), rx=0.03 * breath)
            ps.rot("UpperArm.L", rx=-0.3, ry=0.12)
            ps.rot("UpperArm.R", rx=-0.3, ry=-0.12)
            ps.rot("LowerArm.L", rx=-1.1)
            ps.rot("LowerArm.R", rx=-1.1)
        ps.key(f + 1)
    _finish(rig, act, name, frames)


def talk(ps, name="Talk", seconds=4.0):
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        ps.reset()
        drop = 0.015 * k
        ps.move("Hips", (0.01 * k * math.sin(w), 0, -drop))
        ps.leg("L", drop, -0.04 * k, 0.0, spread=0.04)
        ps.leg("R", drop, 0.07 * k, 0.0, spread=0.04)
        ps.rot("Chest", rx=0.02 * math.sin(w * 2), rz=0.1 * math.sin(w))
        ps.rot("Head", rx=0.07 * math.sin(w * 3), rz=0.2 * math.sin(w + 1.0))
        g = math.sin(w * 2 + 0.3)
        ps.rot("UpperArm.R", rx=-0.35 - 0.2 * g, ry=-0.2)
        ps.rot("LowerArm.R", rx=-1.1 - 0.25 * math.sin(w * 3), rz=-0.3)
        ps.rot("Hand.R", rx=0.2 * math.sin(w * 4))
        ps.rot("UpperArm.L", rx=0.02, ry=0.1)
        ps.rot("LowerArm.L", rx=-0.35 - 0.3 * max(0.0, math.sin(w + 2.0)))
        ps.key(f + 1)
    _finish(rig, act, name, frames)


def serve(ps, name="Serve", seconds=2.0):
    """Tray on the left hand, bend in, set something down with the right, straighten up."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        reach = smooth(t / 0.35) * (1 - smooth((t - 0.65) / 0.35))
        ps.reset()
        drop = (0.015 + 0.05 * reach) * k
        ps.move("Hips", (0, 0, -drop))
        ps.leg("L", drop, -0.04 * k, 0.0, spread=0.04)
        ps.leg("R", drop, 0.12 * k, 0.0, spread=0.04)
        ps.rot("Hips", rx=0.15 * reach)
        ps.rot("Spine", rx=0.2 * reach)
        ps.rot("Chest", rx=0.1 * reach, rz=0.1 * reach)
        ps.rot("Head", rx=0.2 * reach)
        _carry_arm(ps, "L")
        ps.rot("UpperArm.R", rx=-0.2 - 0.9 * reach, ry=-0.15)
        ps.rot("LowerArm.R", rx=-0.3 - 0.5 * reach)
        ps.rot("Hand.R", rx=0.3 * reach)
        ps.key(f + 1)
    _finish(rig, act, name, frames, cyclic=False)


def throw(ps, name="Throw", seconds=0.9):
    """An overhand lob: step in with the left foot, wind the right arm back, let fly, follow through."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        wind = smooth(t / 0.4) * (1 - smooth((t - 0.4) / 0.15))
        fly = smooth((t - 0.4) / 0.2)
        settle = smooth((t - 0.7) / 0.3)
        ps.reset()
        drop = (0.02 + 0.03 * fly * (1 - settle)) * k
        ps.move("Hips", (0, 0, -drop))
        ps.leg("L", drop, (0.05 + 0.13 * max(wind, fly * (1 - settle))) * k, 0.0, spread=0.05)
        ps.leg("R", drop, -0.1 * k, 0.0, spread=0.04)
        twist = 0.35 * wind - 0.4 * fly * (1 - settle)
        ps.rot("Spine", rx=-0.08 * wind + 0.15 * fly * (1 - settle), rz=twist * 0.5)
        ps.rot("Chest", rz=twist * 0.6)
        ps.rot("Head", rz=-twist * 0.7)
        arm = 0.9 * wind - 2.3 * fly + 1.4 * fly * settle
        ps.rot("UpperArm.R", rx=arm, ry=-0.35 * wind - 0.15)
        ps.rot("LowerArm.R", rx=-1.5 * wind - 0.2 * (1 - wind))
        ps.rot("Hand.R", rx=0.4 * wind - 0.3 * fly)
        ps.rot("UpperArm.L", rx=-0.9 * wind + 0.4 * fly, ry=0.2)
        ps.rot("LowerArm.L", rx=-0.6)
        ps.key(f + 1)
    _finish(rig, act, name, frames, cyclic=False)


def climb(ps, name="Climb", seconds=1.0):
    """Up a ladder: hand over hand, knee over knee, the body close in to the rungs."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        ps.reset()
        drop = 0.04 * k
        ps.move("Hips", (0, 0, -drop))
        for side, ph in (("L", 0.0), ("R", math.pi)):
            s = 0.5 + 0.5 * math.sin(w + ph)
            ps.leg(side, drop, (0.06 + 0.1 * s) * k, 0.32 * s * k, foot_pitch=-0.2 * s, spread=0.06)
            ps.rot("UpperArm." + side, rx=-2.3 - 0.45 * (1 - s), ry=(0.12 if side == "L" else -0.12))
            ps.rot("LowerArm." + side, rx=-0.5 - 0.6 * s)
            ps.rot("Hand." + side, rx=-0.3)
        ps.rot("Spine", rx=-0.06)
        ps.rot("Head", rx=-0.3)
        ps.key(f + 1)
    _finish(rig, act, name, frames)


def mantle(ps, name="Mantle", seconds=0.55):
    """Hands on the ledge, push down, knees up and over."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        push = smooth(t / 0.5)
        tuck = smooth((t - 0.25) / 0.45) * (1 - smooth((t - 0.8) / 0.2))
        ps.reset()
        drop = 0.05 * k
        ps.move("Hips", (0, 0, -drop))
        ps.leg("L", drop, 0.12 * k * tuck, 0.3 * k * tuck, spread=0.05)
        ps.leg("R", drop, 0.05 * k * tuck, 0.22 * k * tuck, spread=0.05)
        ps.rot("Spine", rx=0.35 * push * (1 - 0.5 * tuck))
        ps.rot("Chest", rx=0.15 * push)
        ps.rot("Head", rx=-0.25 * push)
        for side in ("L", "R"):
            ps.rot("UpperArm." + side, rx=-1.9 + 1.1 * push, ry=(0.18 if side == "L" else -0.18))
            ps.rot("LowerArm." + side, rx=-0.9 + 0.7 * push)
            ps.rot("Hand." + side, rx=0.6 * push)
        ps.key(f + 1)
    _finish(rig, act, name, frames, cyclic=False)


def tip_hat(ps, name="TipHat", seconds=1.6):
    """Good evening: two fingers to the hat brim and a small nod."""
    frames = int(seconds * FPS)
    rig = ps.rig
    _clear(rig)
    act = _begin(rig, name)
    k = ps.k
    for f in range(frames + 1):
        t = f / frames
        up = smooth(t / 0.35) * (1 - smooth((t - 0.6) / 0.35))
        nod = math.sin(math.pi * smooth((t - 0.25) / 0.4)) if 0.25 < t < 0.65 else 0.0
        ps.reset()
        drop = 0.012 * k
        ps.move("Hips", (0, 0, -drop))
        ps.leg("L", drop, -0.03 * k, 0.0, spread=0.04)
        ps.leg("R", drop, 0.05 * k, 0.0, spread=0.04)
        ps.rot("Head", rx=0.18 * nod)
        ps.rot("Chest", rx=0.04 * nod)
        ps.rot("UpperArm.R", rx=-2.05 * up + 0.03, ry=-0.17 + 0.05 * up)
        ps.rot("LowerArm.R", rx=-1.95 * up - 0.2)
        ps.rot("Hand.R", rx=-0.2 * up)
        ps.rot("UpperArm.L", rx=0.03, ry=0.17)
        ps.rot("LowerArm.L", rx=-0.22)
        ps.key(f + 1)
    _finish(rig, act, name, frames, cyclic=False)


## the speeds the game divides by when it plays each cycle (actor.gd WALK_REF, player.gd)
WALK_V = 1.7
RUN_V = 3.9
SNEAK_V = 1.0


def build_all(rig, k, kinds, gait=None):
    """gait: this man's own walk (stride a, stance, lean, arm_swing, elbow, lift, bob, sway)."""
    ps = Poser(rig, k)
    g = {"stance": 0.6, "a": 0.36, "lift": 0.11, "hip_base": 0.045, "bob": 0.018, "lean": 0.04, "arm_swing": 0.32, "elbow": 0.22, "sway": 0.035}
    g.update(gait or {})
    if "base" in kinds:
        idle(ps, "Idle")
        cycle(ps, "Walk", P=1.0, stance=g["stance"], a=g["a"], lift=g["lift"], hip_base=g["hip_base"], bob=g["bob"], lean=g["lean"],
              arm_swing=g["arm_swing"], elbow=g["elbow"], v_ref=WALK_V, sway=g["sway"])
    if "run" in kinds:
        cycle(ps, "Run", P=0.66, stance=0.36, a=0.44, lift=0.28, hip_base=0.07, bob=0.03, lean=0.22, arm_swing=0.7, elbow=1.25, run=True, v_ref=RUN_V)
    if "sneak" in kinds:
        idle(ps, "SneakIdle", 3.0, sneak=True)
        cycle(ps, "SneakWalk", P=1.3, stance=0.66, a=0.4, lift=0.1, hip_base=0.3, bob=0.012, lean=0.62, arm_swing=0.2, elbow=1.0, sneak=True, v_ref=SNEAK_V)
    if "carry" in kinds:
        idle(ps, "CarryIdle", 3.0, carry=True)
        cycle(ps, "CarryWalk", P=1.05, stance=0.6, a=0.34, lift=0.09, hip_base=0.045, bob=0.012, lean=0.0, arm_swing=0.2, elbow=0.25, carry=True, v_ref=WALK_V)
        serve(ps, "Serve")
    if "sit" in kinds:
        sit(ps, "Sit")
        sit(ps, "SitTalk", talk=True, seconds=5.0)
        sit(ps, "SitWrite", write=True, seconds=4.0)
        sit(ps, "SitDrink", drink=True, seconds=5.0)
    if "talk" in kinds:
        talk(ps, "Talk")
    if "act" in kinds:
        throw(ps, "Throw")
        climb(ps, "Climb")
        mantle(ps, "Mantle")
    if "tip" in kinds:
        tip_hat(ps, "TipHat")
    if "lantern" in kinds:
        idle(ps, "LookAround", 6.0, lantern=True, look=True)
        cycle(ps, "LanternWalk", P=1.1, stance=0.62, a=0.34, lift=0.09, hip_base=0.045, bob=0.015, lean=0.03, arm_swing=0.25, elbow=0.2, lantern=True, v_ref=WALK_V)
    ps.reset()
