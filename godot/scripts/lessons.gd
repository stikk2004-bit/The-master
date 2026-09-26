extends RefCounted
## The club's four studies. Each chapter has a grown-up version, a kids version,
## and one question to check yourself. "sim" is the Money Machine step it links to (-1 for none).

const VOLUMES := [
	{
		"title": "Understanding money",
		"blurb": "What money is, where it came from, and where new dollars come from today.",
		"chapters": [
			{
				"title": "What money does",
				"grown": "Before money, people traded straight across. A farmer with eggs who needed shoes had to find a shoemaker who wanted eggs, on the same day. That almost never works out, so people started using one thing everybody would take.\n\nAnything that does that job well does three things. It's a [b]medium of exchange[/b]: you trade it for what you need. It's a [b]unit of account[/b]: prices are measured in it, so you can compare a truck and a sack of feed. And it's a [b]store of value[/b]: it still buys something next month.\n\nShells, salt, cattle, silver, and gold have all been money at one time or another. What they had in common wasn't what they were made of. It was that people agreed to take them.",
				"kid": "Long ago people traded things straight across, like eggs for shoes. But what if the shoemaker didn't want eggs? That's a problem.\n\nSo people picked one thing everybody would take. That thing is money. Money does three jobs: you can [b]trade[/b] it for stuff, you can [b]count prices[/b] with it, and you can [b]save[/b] it for later.\n\nShells, salt, and gold have all been money. The trick is that everybody has to agree to take it.",
				"q": "Which of these is NOT one of money's three jobs?",
				"options": ["Something you trade for what you need", "A way to measure prices", "Something that has to be made of gold"],
				"answer": 2,
				"why": "Money has to be something people will take, count prices in, and save. It doesn't have to be gold, and most money today isn't.",
				"sim": -1
			},
			{
				"title": "From gold to paper to numbers",
				"grown": "For a long time, money was metal: gold and silver coins. Metal is heavy and easy to steal, so people left it with goldsmiths and banks and carried paper receipts instead. The receipts started changing hands as money.\n\nThe United States tied the dollar to gold for most of its history. In 1933 Americans were made to turn in most of their gold coins, and in 1971 President Nixon ended the last link, when foreign governments could no longer trade dollars for gold.\n\nSince then the dollar has been [b]fiat money[/b]. Fiat is Latin for 'let it be done.' A dollar is worth something because the law says it settles debts, the government takes only dollars for taxes, and all of us accept it. There's nothing in a vault behind it.",
				"kid": "Money used to be gold and silver coins. Coins are heavy, so people kept their gold at the bank and carried a paper ticket that said 'this is worth some gold.' People started trading the tickets instead.\n\nIn America, dollars were tied to gold for a long time. In 1971 that stopped. Now a dollar isn't backed by gold at all. It's worth something because the government says so, you pay your taxes with it, and everybody takes it. That's called [b]fiat money[/b].",
				"q": "What makes a dollar worth something today?",
				"options": ["There's gold in a vault for every dollar", "The law, taxes, and everybody agreeing to take it", "The paper it's printed on"],
				"answer": 1,
				"why": "No gold has stood behind the dollar since 1971. It works because the law says it settles debts, the government requires it for taxes, and all of us accept it.",
				"sim": 0
			},
			{
				"title": "Where new dollars come from",
				"grown": "Here's what most people are never told. Most of the money you can spend, the dollars in checking accounts, is made by regular banks when they make loans. When a bank lends you ten thousand dollars, it doesn't hand you somebody else's savings. It types ten thousand new dollars into your account. The loan is the bank's asset. Your deposit is the bank's debt to you. Both appear at once, and when you pay the loan back, both disappear.\n\nThe government adds money too. When it spends more than it collects in taxes, it borrows by selling bonds, and the spending lands in people's accounts as new deposits. Taxes pull money back out.\n\nThe Federal Reserve makes the money banks use with each other, called [b]reserves[/b], and it supplies the paper bills. When the Fed buys bonds, it pays with brand new reserves.",
				"kid": "Most money today is made by banks! When a bank gives someone a loan, it doesn't take money out of anybody's piggy bank. It just types new money into the person's account. Poof, new money.\n\nWhen the loan gets paid back, that money disappears again.\n\nThe government can add money too, by spending more than it collects in taxes. Taxes take money back out.",
				"q": "When a bank makes a loan, where does the money come from?",
				"options": ["It takes it out of other people's savings", "It creates a new deposit in the borrower's account", "It asks the government to print it"],
				"answer": 1,
				"why": "The loan and a matching new deposit show up together. That deposit is new money. Paying the loan back erases it.",
				"sim": 1
			},
			{
				"title": "Why prices go up",
				"grown": "If the amount of money in a town grows faster than the amount of stuff the town makes, prices tend to rise. More dollars are chasing the same eggs, trucks, and houses. That's [b]inflation[/b], and it means each dollar buys a little less than it used to.\n\nIt isn't the only cause. A bad harvest, or a hurricane that shuts the refineries, can push prices up too, because there's less stuff. But over long stretches, a lot more money usually means higher prices.\n\nA dollar in 1970 bought about what eight dollars buys today. That's why cash under a mattress for decades is a slow way to lose it.",
				"kid": "If a town gets a lot more money but doesn't make more stuff, prices go up. More dollars are trying to buy the same toys and candy. That's called [b]inflation[/b].\n\nIt means a dollar buys a little less each year. A candy bar that cost a dime a long time ago costs a lot more now.",
				"q": "What usually happens if money grows much faster than the stuff a town makes?",
				"options": ["Prices go up", "Prices go down", "Nothing changes"],
				"answer": 0,
				"why": "More dollars chasing the same goods tends to push prices up. That's inflation.",
				"sim": 4
			}
		]
	},
	{
		"title": "Systems thinking",
		"blurb": "How the parts push on each other, in a budget, a town, or a whole economy.",
		"chapters": [
			{
				"title": "Stocks and flows",
				"grown": "A [b]stock[/b] is anything that piles up: water in a bathtub, money in savings, fish in a pond, debt on a credit card. A [b]flow[/b] is what fills it or drains it.\n\nThe stock only changes because of the flows. If more runs out than runs in, it shrinks, no matter how big it started. A big paycheck with bigger bills still ends at zero.\n\nOnce you see stocks and flows, you ask better questions. Not 'how much do I have?' but 'what's coming in, what's going out, and which way is it heading?'",
				"kid": "Think of a bathtub. The water in the tub is the [b]stock[/b]. The faucet and the drain are the [b]flows[/b].\n\nYour piggy bank works the same way. Money you get is the faucet. Money you spend is the drain. If the drain is bigger than the faucet, the piggy bank empties out.",
				"q": "Your savings is a stock. What changes it?",
				"options": ["Only how much you started with", "The flows in and out", "The day of the week"],
				"answer": 1,
				"why": "A stock only changes through its flows. Money in minus money out tells you where it's headed.",
				"sim": -1
			},
			{
				"title": "Loops that feed themselves",
				"grown": "Some flows depend on the stock itself. That makes a [b]feedback loop[/b].\n\nA [b]reinforcing loop[/b] feeds itself. Interest earns interest, so savings grow faster the bigger they get. Debt works the same way in the other direction. Rumors, bank runs, and hot stocks can all run on reinforcing loops.\n\nA [b]balancing loop[/b] pushes things back toward steady. When prices climb, people buy less, and prices settle. When you're hungry you eat, and then you stop.\n\nMost of what happens in an economy is loops pushing against loops.",
				"kid": "Some things grow on themselves, like a snowball rolling downhill. The bigger it gets, the more snow it picks up. Money with interest does that, and so do debts. That's a [b]reinforcing loop[/b].\n\nOther things balance out, like a thermostat. When it gets too hot, the air comes on. That's a [b]balancing loop[/b].",
				"q": "Interest earning more interest is an example of what?",
				"options": ["A reinforcing loop", "A balancing loop", "A flow that never changes"],
				"answer": 0,
				"why": "Each round of interest makes the next round bigger. It feeds itself.",
				"sim": -1
			},
			{
				"title": "Incentives, and then what?",
				"grown": "People do what they're rewarded for. If you want to understand why something keeps happening, ask who gets paid when it does.\n\nThen ask [i]and then what?[/i] Every choice has a first effect you can see and later effects you might not. Cheap borrowing feels good today, and then more money and more debt pile up later. A bank that earns interest on every loan has a reason to make a lot of them.\n\nSystems thinking is mostly the habit of asking those two questions before you decide.",
				"kid": "People usually do what they get rewarded for. If a store gives a prize for buying candy, people buy more candy.\n\nWhen you make a choice, ask [i]and then what?[/i] Eating all your candy today feels great. And then what? No candy tomorrow.",
				"q": "What two questions does systems thinking ask?",
				"options": ["Who gets rewarded, and then what?", "How much and how fast?", "Where and when?"],
				"answer": 0,
				"why": "Follow the incentives, then follow the effects past the first one.",
				"sim": 4
			}
		]
	},
	{
		"title": "Personal financial awareness",
		"blurb": "Your own money, looked at honestly.",
		"chapters": [
			{
				"title": "Where your money goes",
				"grown": "Start with three questions. What comes in? What goes out? Where does the rest go?\n\nWrite it down for one month. Not a budget yet, just the truth. Every dollar in and every dollar out, even the gas station coffee. Most people find money leaking somewhere they didn't expect.\n\nThis is the stock and flow idea from Volume II, pointed at your own life. Your account is the stock. Your paycheck and your bills are the flows.",
				"kid": "Ask three questions: How much do I get? How much do I spend? What's left?\n\nTry writing down everything you spend for a week. You might be surprised where it goes.\n\nNeeds are things you have to have, like food and a coat. Wants are things that are nice, like a new game. Wants are fine. Just take care of the needs first.",
				"q": "What's the first step to understanding your own money?",
				"options": ["Write down what comes in and what goes out", "Open a credit card", "Guess"],
				"answer": 0,
				"why": "You can't fix what you haven't measured. A month of honest tracking comes first.",
				"sim": -1
			},
			{
				"title": "Interest works for you or against you",
				"grown": "Interest is the price of using money over time. When you save, a bank pays you interest. When you borrow, you pay it.\n\nThe gap between those two is big. A savings account might pay a few percent a year. A credit card commonly charges twenty percent or more. Carry a thousand dollars on that card for a year and you can pay two hundred dollars or more just to borrow it.\n\nThat's the reinforcing loop from Volume II. On your side, it builds. Against you, it digs.",
				"kid": "Interest is the extra money you pay when you borrow, or the extra money you get when you save.\n\nWhen you save, interest is like a little thank-you from the bank. When you borrow, interest is what it costs you. Borrowing on a credit card can cost a lot, so it's best to borrow only when you really need to.",
				"q": "You carry $1,000 on a card charging 24% a year. About how much interest could you pay in a year?",
				"options": ["About $24", "About $240", "About $2,400"],
				"answer": 1,
				"why": "24 percent of 1,000 is 240. That's money gone just for borrowing.",
				"sim": -1
			},
			{
				"title": "A cushion and a plan",
				"grown": "Keep a cushion. Even a small emergency fund means a flat tire doesn't turn into a new debt.\n\nThen remember what Volume I said about inflation. Cash sitting still for years slowly buys less. That doesn't mean spend it. It means know what your money is doing, and learn your options before somebody tries to sell you one.\n\nNobody in this club will tell you what to buy. We'll teach you enough to ask good questions.",
				"kid": "Save a little money for surprises, like a broken bike. That's called a cushion.\n\nAnd remember, money that sits still for a long time buys a little less each year. So learn about money early. That's why you're here.",
				"q": "Why keep an emergency cushion?",
				"options": ["So a surprise bill doesn't turn into new debt", "Because cash always grows", "To spend on wants"],
				"answer": 0,
				"why": "A cushion covers the flat tire so you don't have to borrow for it.",
				"sim": -1
			}
		]
	},
	{
		"title": "Self-improvement through structured learning",
		"blurb": "How to keep what you learn.",
		"chapters": [
			{
				"title": "One subject at a time",
				"grown": "Knowing a thing once isn't the same as knowing it.\n\nPick one subject at a time. Read a little every day instead of a lot once a week. Ten pages every morning is over three thousand pages a year.\n\nThe club works the same way on purpose: a set reading, a steady pace, and one study after another, in order.",
				"kid": "Getting smarter works like building muscle. You do a little bit, over and over.\n\nPick one thing to learn. Read or practice a little every day, even ten minutes. Little bits add up to a lot.",
				"q": "Which habit builds more knowledge over a year?",
				"options": ["A little every day", "Cramming once a month", "Waiting until you feel like it"],
				"answer": 0,
				"why": "Small, steady reading adds up. Ten pages a day is thousands of pages a year.",
				"sim": -1
			},
			{
				"title": "Explain it plainly",
				"grown": "Write down what you learned in your own words. If you can't explain it plainly, you don't have it yet.\n\nThe best test is teaching it. Try explaining where new money comes from to a ten year old. If they get it, you've got it. If you get stuck, you just found the part to study again.",
				"kid": "After you learn something, try to teach it to somebody, like a parent or a friend.\n\nIf you can teach it, you know it. If you get stuck, that's the part to learn again.",
				"q": "What's the best test that you really understand something?",
				"options": ["You can explain it plainly to someone else", "You read it once", "It sounds familiar"],
				"answer": 0,
				"why": "Teaching it back shows you exactly what you know and what you don't.",
				"sim": -1
			},
			{
				"title": "Show up",
				"grown": "Structure only works if you keep it. The folks who come to every meeting, do the reading, and can be counted on by the others are the ones who get asked to stay.\n\nThat's the whole secret, and it isn't much of one. The first three studies give you the knowledge. This one is how you keep it.",
				"kid": "Show up when you said you would, and do your part. People notice.\n\nThat's how you earn trust, in the club and everywhere else.",
				"q": "What keeps structured learning working?",
				"options": ["Showing up and doing the reading every time", "Being the smartest in the room", "Buying the right book"],
				"answer": 0,
				"why": "Consistency beats talent. The people who keep showing up are the ones who keep learning.",
				"sim": -1
			}
		]
	}
]
