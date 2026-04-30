# To-do's

## Modular refactoring

- [ ] Validate bootstrapping method (ongoing); it should dump the created environment variables to a file so that we have no further environment creations (the user is responsible for not destroying the environment or recreating it). The supported installable applications are present on the main script but are not installed. One must call the function they want to install the required software (maybe make this available in the UI and disable those already installed). A scripts folder allows for adding new software and is scanned on start for sourcing new functions.

- [ ] Currently the UI scans only the local repositories; it would be interesting to add support for a default location in WSL and support a configuration file for trying to load repositories from any path.

- [ ] Add buttons for common software so that we do not need to pin them to the taskbar; it will enable/disable buttons based on the installation status of the application.

## New features

- [ ] Add lua and golang support.

- [ ] Add Java Adoptium to be able to support Clojure.

- [ ] Install Clojure CLI GitHub - casselc/clj-msi with lessmsi

## Bugs

- [ ] Why does Curl fail to download Erlang (or maybe GitHub issue)?