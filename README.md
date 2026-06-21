===============================================================================
  HOW TO INSTALL RCLONE ON WINDOWS
  A complete step-by-step guide
  (Part of OBS Chunk Auto-Uploader by PawelPL101)
===============================================================================

rclone is a free, open-source tool that this uploader uses to send your
recordings to the cloud. You only need to install it ONCE.

This tool works with ANY cloud provider rclone supports (Google Drive, Dropbox,
OneDrive, Backblaze B2, Amazon S3, and 60+ more). The setup steps below use
Google Drive as an example in Step 6, but rclone's config will guide you through
whichever provider you choose - the only part that differs is the sign-in.

This guide walks you through it from start to finish. It looks long, but it
only takes about 5-10 minutes.


-------------------------------------------------------------------------------
STEP 1: DOWNLOAD RCLONE
-------------------------------------------------------------------------------

1. Open your web browser and go to:

       https://rclone.org/downloads/

2. Find the section called "Windows".

3. Click the download link for:

       Windows  -  Intel/AMD - 64 Bit

   (This is the right one for virtually all modern Windows PCs. If you somehow
    have a 32-bit PC, choose the "386" version instead, but this is very rare.)

4. This downloads a ZIP file, something like:

       rclone-v1.xx.x-windows-amd64.zip


-------------------------------------------------------------------------------
STEP 2: EXTRACT THE ZIP
-------------------------------------------------------------------------------

1. Find the downloaded ZIP file (usually in your Downloads folder).

2. Right-click it and choose "Extract All...".

3. Extract it somewhere temporary, like your Downloads folder. You'll get a
   folder containing several files (rclone.exe plus some documentation files).


-------------------------------------------------------------------------------
STEP 3: PUT THE RCLONE FILES IN THE RIGHT PLACE
-------------------------------------------------------------------------------

1. Open File Explorer and go to your C: drive (This PC > Local Disk (C:)).

2. Create a new folder there named exactly:

       rclone

   So the full path is:

       C:\rclone

3. Open the extracted rclone folder. Copy its contents into C:\rclone.

   IMPORTANT: Do NOT delete everything except rclone.exe. Keep the program
   files. You only need to delete the documentation files if you want to tidy
   up - specifically the README and any "how-to" / license text files. The
   rest (including rclone.exe) should go into C:\rclone.

   You should now have, at minimum:

       C:\rclone\rclone.exe

   (You can delete the leftover ZIP and the temporary extracted folder
    afterward.)


-------------------------------------------------------------------------------
STEP 4: ADD RCLONE TO YOUR PATH (SO YOU CAN RUN IT FROM ANYWHERE)
-------------------------------------------------------------------------------

This step lets you type "rclone" in any terminal instead of the full path. It
is the proper way to install rclone.

1. Open "This PC" (or "My Computer") in File Explorer.

2. Right-click an empty area and choose "Properties".
   (This opens the System > About settings page.)

3. On that page, find and click "Advanced system settings".
   (It's under "Related links" near the device specifications.)

4. In the window that opens, click the "Environment Variables..." button.

5. In the TOP box ("User variables"), click on the row named "Path" to select
   it, then click "Edit...".

6. A list window opens. Click "New", then click "Browse...".

7. Navigate to your C: drive, open the "rclone" folder, select "rclone.exe",
   and confirm.
   (Tip: if Browse only lets you pick folders, just select the C:\rclone
    folder itself - adding the folder to PATH also works.)

8. Click "OK" to close each window, all the way out.


-------------------------------------------------------------------------------
STEP 5: VERIFY IT WORKS
-------------------------------------------------------------------------------

1. Open a NEW Command Prompt or PowerShell window.
   (Important: open a fresh one - PATH changes only apply to new windows.)

2. Type this command and press Enter:

       rclone version

3. If you see something like "rclone v1.xx.x", it's installed correctly!

   If you get an error saying it isn't recognized, double-check Step 4 - the
   PATH entry may not point to the right place, or you may need to open a
   brand-new terminal window.


-------------------------------------------------------------------------------
STEP 6: CONNECT RCLONE TO YOUR CLOUD (GOOGLE DRIVE EXAMPLE)
-------------------------------------------------------------------------------

NOTE: This uploader works with ANY cloud service rclone supports - NOT just
Google Drive. That includes Dropbox, OneDrive, Backblaze B2, Amazon S3, Mega,
pCloud, Box, Proton Drive, and 60+ others. The steps below use Google Drive as
an example because it's the most common, but the process is the same for any
provider: run "rclone config", create a new remote, and pick your provider from
the list. rclone will then prompt you through that provider's sign-in. The only
part that differs between providers is the sign-in screen.

(If you pick a different provider, just choose its number from the storage list
in step 2 below instead of Google Drive, and follow rclone's prompts. When
SETUP for this uploader asks which cloud you're using, pick the matching one.)

Now you'll link rclone to your cloud account. The SETUP for this uploader can
launch this for you, but here are the manual steps in case you want to do it
yourself or something goes wrong.

1. In Command Prompt or PowerShell, run:

       rclone config

2. You'll see a menu. Follow these answers:

       - Type:  n     (for "New remote")  then press Enter
       - name>  gdrive                    then press Enter
                (You can name it anything, but remember what you choose -
                 you'll enter this name during SETUP. "gdrive" is a good
                 simple choice for Google Drive. If you're using a different
                 provider, pick a fitting name like "dropbox" or "onedrive".)

       - You'll see a long numbered list of storage types. Look for the one
         labeled "Google Drive" (it may be named "drive"). Type the NUMBER
         next to it, then press Enter.

       - client_id>        just press Enter (leave blank)
       - client_secret>    just press Enter (leave blank)

       - scope>  Type the number for option 1 ("Full access all files"),
                 then press Enter.

       - root_folder_id>     just press Enter (leave blank)
       - service_account_file>  just press Enter (leave blank)

       - Edit advanced config?  Type  n  then Enter
       - Use web browser to automatically authenticate?  Type  y  then Enter

3. Your web browser will open. Sign in to the cloud account where you want
   your recordings stored, and click "Allow".

4. Back in the terminal:

       - Configure this as a team drive?  Type  n  then Enter
       - It shows a summary - type  y  to confirm, then Enter
       - Type  q  to quit the config menu.

5. Test that it connected by running (replace "gdrive" with your remote name
   if you chose a different one):

       rclone lsd gdrive:

   If it lists folders from your cloud (or shows nothing but no error),
   you're connected!


-------------------------------------------------------------------------------
DONE!
-------------------------------------------------------------------------------

rclone is now installed, on your PATH, and connected to your cloud storage.
You can now run SETUP.bat for the OBS Chunk Auto-Uploader, which handles the
rest. When SETUP asks for your rclone path, you can simply type:

       rclone

   ...since it's on your PATH now. (Or give the full path C:\rclone\rclone.exe
    if you prefer.)

If you ever need to reconnect (for example if the connection expires), run:

       rclone config reconnect gdrive:


-------------------------------------------------------------------------------
TROUBLESHOOTING
-------------------------------------------------------------------------------

"rclone is not recognized"
    -> rclone isn't on your PATH yet, or you're using an old terminal window.
       Open a BRAND-NEW Command Prompt / PowerShell and try again. If it still
       fails, recheck Step 4 and make sure the PATH entry points to C:\rclone
       (or directly to C:\rclone\rclone.exe).

The browser didn't open during config
    -> You can copy the link rclone prints into your browser manually.

"Failed to configure token"
    -> Run "rclone config" again and make sure you complete the cloud sign-in
       and click Allow.

The cloud provider says the app isn't verified
    -> This is normal for rclone. Click "Advanced" then "Go to rclone (unsafe)"
       - it is safe; this warning appears for all rclone users because it's a
       generic open-source tool, not a registered commercial app.

===============================================================================
