# Contribution Guidelines

This small application is very narrowly scoped, so firstly - be wary of expanding that scope. 

I'm not against good ideas, but considering this was built in roughly two hours total, I would probably suggest that most things are better off with their own implementation.

That goes for things such as usage graphs over time, token rates, etc etc - all those things are better solved by existing solutions - I don't want this tool to become analytics, it is designed to replace manual checking in multiple places. 

That being said, extending this to other AI providers might be an option - but it might also be that I choose not to incorporate other providers For Fear That It Introduces Something Scary. 

Do remember that this little piece of code holds on to credentials for AI providers, and has the possibility of causing economic harm - or if externally exposed - turning your machine into an autonomous botnet.

So yeah, I am wary of accepting changes. I trust myself, I trust the code that I have reviewed and checked for issues, and I trust the security reviews that I've run with claude and codex to check for any potential hazards when doing this. 

That being said - here are some basic contribution guidelines:

# Things to consider when contributing

## New features may not be desired

This is not a swiss army knife. Also, I might be lazy. In fact I am. And that means, the more features this supports, the more stuff I will need to support in the future. To an extent that also goes for supporting all kinds of AI providers - simply put, if I do not have an account with the provider to be able to measure remaining headroom, I will not be able to keep track if it changes api or mechanism in the future, so supporting others than the ones I have/use is probably a bit tricky unless I can get some proactive testers. 

In other words, you're probably better off making a fork of this and building it yourself - which I encourage :) 

## Bugs should be understandable

Understandable does not mean thoroughly reported. I do not need stack traces or dumps (but of course, feel free - as long as they're safe to share). What I do need though is an explanation of what you wish to achieve and why you believe it should be possible to achieve in the application, as well as what prohibits you currently from achieving it. 

## Always assume best intentions

Whenever reviewing a contribution, assume best intentions. Noone is deliberately taking their time to introduce poor code or stupid solutions. There may be well-meaning but sloppy/insecure/poor contributions.  They have the best intentions. But they just don't contribute positively in the direction we want to go. As such, acknowledge the positive direction, and kindly illuminate the issues, even if they are subjective, that prohibit us from incorporating the proposed changes.

## DO use AI 

I built this with AI, it would be horrendously hypocritical of me to suggest you contribute otherwise. This also goes for the actual PR text as well - if AI makes it clear to read and understand, I'm all for it. Just make sure you read it and understand it first before letting it loose on me, I am not your proofreader :)

# Final thoughts

I don't expect this thing to get a lot of updates. At some point in time it may even be fully deprecated because it's not really needed anymore. I mean, it wasn't needed two years ago - who knows what the future brings. 