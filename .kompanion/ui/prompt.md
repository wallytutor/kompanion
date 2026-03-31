- Create a graphical application in .NET that will run script pointed to by the environment variable `$env:KOMPANION_SOURCE`. The application will then read environment variable `$env:KOMPANION_REPO` and display the list of directories in that path. It will filter only directories that contain a .git folder, indicating they are Git repositories. For each repository, the UI will provide three buttons: "Launch", "Pull", and "Push". The UI will look like this:

```
| Repo | Launch | Pull | Push |
|------|--------|------|------|
| Dir1 | [Launch] | [Pull] | [Push] |
| Dir2 | [Launch] | [Pull] | [Push] |
| ...  | ...    | ...  | ...  |
```

- If $env:KOMPANION_SOURCE is not set or the path does not exist, the application will display an appropriate error message and do nothing.

- The "Launch" will launch VSCode at the repository path with the specified extensions and user settings as provided below. It will run in the background, so that if one closes the app, VSCode will continue running. The "Pull" and "Push" buttons will execute the corresponding Git commands in the repository path.

```ps1
Code.exe $path `
    --extensions-dir $env:VSCODE_EXTENSIONS `
    --user-data-dir  $env:VSCODE_SETTINGS
```

- The application will also have a "Refresh" button that will re-read the repositories from the specified path and update the UI accordingly.

- The application will be built using Windows Forms or WPF in .NET, and it will handle all necessary error checking and user feedback for actions performed.

- The application will have a nice open source icon so that it looks nice in the taskbar and can be pinned to the taskbar for easy access.

- The application will log actions to a file under `$env:KOMPANION_LOGS` with timestamps for each action performed (e.g., launching VSCode, pulling, pushing).

- When pushing/pulling, the application will capture outputs to the log, so if anything goes wrong, there is direct access to the information.

- Coding practices will include line lenghts limited to 100 characters, proper error handling, and comments explaining the code logic.

- The package is to be built as a standalone application, so that it does not depend on .NET being installed. Use the single-file approach.

- Add a README.md file explaining how you conceived the application (all commands to create a similar app, as a tutorial), how to build it, and how to use it.

- An edge case: add the repository located at `$env:KOMPANION_DIR` to the top of the list. This is the main project repository and it is not found in the aforementioned path, but it should be easily accessible.

- Instead of exiting when the user clicks the close button, the application will minimize to the system tray. The tray icon will have a context menu with options to restore the window or exit the application.

- Split the UI into two tabs: "Repositories" and "Settings". The "Repositories" tab will contain the list of repositories and their corresponding buttons (exactly the same existing UI), while the "Settings" is for now just a placeholder for future settings, but it will have a label that says "Settings coming soon!" to indicate that it's not yet implemented.

- The application underwent several iterations of design and development. Please review the code and ensure that it follows best practices for UI design, error handling, and logging. Make sure that the application is user-friendly and provides clear feedback for all actions performed. Additionally, ensure that the application is robust and can handle edge cases gracefully. If required, refactor the code to improve readability and maintainability, while keeping the functionality intact. Update the README.md file to reflect any changes made during the review process, and ensure that it provides clear instructions for building and using the application.

- Add unit tests for ScriptRunner and GitService with mocked process execution wrappers. Add cancellation support for long git operations from the UI. Add a small status history pane in the Settings tab for recent actions/log tail. Also work on a theme with the same colors as the logo.
