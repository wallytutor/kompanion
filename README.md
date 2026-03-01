# Kompanion

## Before you start

If you just need a Python/Rust environment with Git version control and Visual Studio code there is nothing to do, simply open a PowerShell terminal (not legacy *Windows PowerShell*) at this directory and run `.\kompanion.ps1` to install the defaults.

If you do not dispose of a proper code editor, you can simply install Kompanion as described above before editing files as described below.

Under `.kompanion` you will find a `kompanion-sample.json` which allows one to configure packages to be installed. Copy or rename this file to `kompanion.json` and tweak the `true/false` flags for selecting packages. Please notice that the defaults are required for Kompanion to work properly. After saving the file run `.\kompanion.ps1 -RebuildOnStart` and you should be good to go.

Please notice that if some package fails to download, *e.g.* firewall issues, you might need to manually clean the respective folder under `.kompanion\bin` before running again.

## Automatic sourcing

This section describes how to get Kompanion automatically sourced in your user profile for all PowerShell sessions.

Start by creating an environment variable `KOMPANION_SOURCE` pointing to the *full-path* of file `kompanion.ps1`.

For instance, if you are called like me and cloned this repository at `GitHub\kompanion` under your profile, then its value should be `C:\Users\walter\GitHub\kompanion\kompanion.ps1`

Next, start PowerShell and identify the path to your user profile:

```ps1
echo $PROFILE
```

If that file does not exist, create it with:

```ps1
New-Item -ItemType File -Path $PROFILE -Force
```

Now you can run `notepad $PROFILE` to open it and append the following lines:

```ps1
if (Test-Path $env:KOMPANION_SOURCE) {
    . $env:KOMPANION_SOURCE

    # Uncomment the following if you want the terminal to start at
    # the root of this repository; useful for development.
    # cd "$env:KOMPANION_DIR"
} else {
    Write-Host "KOMPANION_SOURCE not found at '$env:KOMPANION_SOURCE'"
}
```