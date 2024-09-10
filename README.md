#  whip

Whip is a macOS app to track app/website usage, and allow setting limits (both usage-based and time-based).

The hidden objective of this project is/was to put LLMs to the test, and build an app from the ground up _entirely_ by having Claude Opus 3.5 write, organize, & modify code. 

## FAQs

**1. Isn't this like Downtime and App Limits on macOS?**

Yes. Unfortunately App Limits doesn't work for me (I wrote this app in Q3/4 2024). I'm not keen to have my usage data harvested by third parties, either, so I decided to build a completely local solution. It might maybe synchronize through iCloud in the future, but no promises.

**2. Was the LLM experiment successful?**

I consider it a partial success.

On one hand, there's no way I would have learned Swift just for this; if I had to write it entirely on my own, I would have probably used Go instead and built a TUI. If you have a clear idea of the architecture and design you want you can write really specific prompts, and with some back and forth you'll be able to get something working at the end. My advice is to keep code-heavy conversations short, since the LLM is liable of getting confused between different versions of the same code.

On the _other_ hand, even uploading all app code as a [Project](https://support.anthropic.com/en/articles/9517075-what-are-projects), it was v-ery annoying to get outputs with sufficient quality (never mind doing so consistently). Issues I had with every feature:
1. It writes the most tightly-coupled code imaginable, even if you ask it to respect common software quality principles like separation of concerns and encapsulation
2. It forgets variables/functions along the way and stops using them, even if you ask it not to
3. It duplicates the "meat" of a function (and signature!), but add it to the code anyway and give it a slightly different name
4. It is pathologically incapable of maintaining a consistent approach, even when told to refer to project files. It happened multiple times that, when asked to correct a single error, Claude decided to change half the app from sync to async.
5. It constantly wastes tokens on apologizing, even if you ask it not to do so in the instructions. It will also constantly tell you you're the smartest person that ever smarted just because you told it a variable would perhaps be better as `private` instead of `public`.

It's like trying to control a junior developer-level squirrel on speed. It can get a lot done in very little time if you're asleep at the wheel, but it's _exhausting_ if you care at all about getting something understandable out of the process.
