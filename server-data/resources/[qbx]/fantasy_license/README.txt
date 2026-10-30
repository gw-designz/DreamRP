Fantasy Scripts — fantasy_license
==================================

Required once per server for every PROTECTED Fantasy Scripts resource.
(Open Source versions don't need it.)

1. Lock your Cfx.re key once at https://fantasyscripts.com/account/licenses
   (the same key as sv_licenseKey in your server.cfg).

2. Put the fantasy_license folder in your server's resources.

3. Add these lines to server.cfg, ABOVE your Fantasy Scripts resources:

     set fantasy_cfx_key "cfxk_your_key_here"
     ensure fantasy_license

   fantasy_cfx_key must be exactly the same as your sv_licenseKey and the key
   locked in the portal. (Resources can't read sv_licenseKey, so it is mirrored.)

4. ensure your protected resources as usual.

Updating a script: replace its folder with the new download and restart it.
Your license and fantasy_license stay as they are — no new key needed.

Only a SHA-256 hash of your Cfx.re key is sent to the license server.
Edit files in config/ and locales/ freely — they stay readable.

Need to move to another server? Open a ticket on our Discord and we'll reset your lock.
