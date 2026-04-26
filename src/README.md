# Kompanion

## Installation approaches (Bootstrap)

**7-zip** is downloaded file by file from [Haskell's Stackage Content](https://github.com/commercialhaskell/stackage-content) repository. This was chosen over the standard 7-zip download because the Stackage Content version contains the normal standalone executable, while the official 7-zip download provides only the minimal version as a portable executable. Files are downloaded individually and placed in a directory that is added to the Kompanion installation.

**curl** is downloaded from the official [curl website](https://curl.se/windows/), which provides a precompiled version for Windows. The zip file contains a directory with the curl folder structure, which is extracted to a temporary location and then moved to the Kompanion installation directory.

**git** is downloaded from the official [Git for Windows](https://github.com/git-for-windows) repository. The zip file contains a directory with the Git folder structure, which is extracted to a temporary location and then moved to the Kompanion installation directory.

**.NET SDK** is downloaded from the official [.NET website](https://dotnet.microsoft.com/en-us/download/dotnet/9.0). The zip file contains a directory with the Git folder structure, which is extracted to a temporary location and then moved to the Kompanion installation directory.

## Installation approaches (General)
