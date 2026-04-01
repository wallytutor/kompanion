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

- Some repositories are used more often than others. Keep a file in `$env:KOMPANION_LOGS` that tracks the usage frequency of each repository. Sort the repositories in the UI based on their usage frequency, with the most frequently used repositories appearing at the top of the list. Update this file every time a repository is launched, pulled, or pushed. This way, users can quickly access their most commonly used repositories without having to scroll through the entire list. Keep Kompanion itself at the top of the list, regardless of its usage frequency, for easy access. Also make sure that VSCode is being launched in maximized mode for better user experience.

- Move the logging to another tabs separate from settings, called "Logs". In this tab, display the logs in a user-friendly way, with timestamps and clear formatting. Also a button to quit the application (as having to exit from the system tray can be a bit unintuitive for some users).

- Ensure that a running instance of the application is a singleton, so that if the user tries to launch it again, it will simply bring the existing instance to the foreground instead of opening a new one.

- Currently we have this file, a README.md, the tests, and the application itself in this directory. Move the application to `KompanionUI` subdirectory, as we will expand this code base in the next steps and modularization is needed. No functionality should be changed, but update the README.md to reflect the new location of the application.

- The above failed, patched with: this is not what I expected; you moved the application AND the tests to a subdirectory, but I asked for the application only! Also, we need a solution file for the whole project. Please move the tests back to the root of the repository, and create a solution file that includes both the application and the tests projects. Update the README.md to reflect these changes, and ensure that all instructions for building and running the application and tests are accurate with the new structure. The application should be in `KompanionUI` subdirectory, while the tests should remain in the root directory under a `KompanionUI.Tests` project. The solution file should be named `Kompanion.slnx` and should be located in the root directory as well.
