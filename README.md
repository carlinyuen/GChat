# GChat
Simple gchat app because the current Hangouts (2013) is really slow and
alternatives are ugly.

## NOTE
No longer continuing development on this. Learned a good deal about XMPP and
dealing with all the state required for a chat client. 

At this point, I realize I don't want to go through the process of figuring out 
how to deal with push notifications, and without APNs, it's not all that useful.
Hope this might come in handy for someone else though.

## TODO
 - Implement remote push notifications (requires a server component that somehow
   echoes being a client at the same time to listen to things coming from
   talk.google.com?).
 - Keep track of unread messages from a user / notifications that come in.
 - Add little badge indicator per row for unread messages from a user.
 - A way to retrieve chat history from the server (not sure talk.google.com
   supports this).
 - A way to allow for logging in with multiple accounts.

## Bugs
 - When the app goes into the background for a long time and comes back,
   sometimes it can't seem to authenticate / load the contact list.

### License
MIT
