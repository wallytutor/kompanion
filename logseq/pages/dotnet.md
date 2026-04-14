- Started script for creating a library with applications and tests:
- ```powershell
   # Create a new solution project:
   dotnet new sln -o 'xl-learn-fsharp'
   cd 'xl-learn-fsharp'
  
   # Create a shared library (from xl-learn-fsharp)
   dotnet new classlib -lang 'F#' -o 'library-xl'
   dotnet sln add 'library-xl/library-xl.fsproj'
  
   # Create a console application (from xl-learn-fsharp)
   dotnet new console -lang 'F#' -o 'console-xl'
   dotnet sln add 'console-xl/console-xl.fsproj'
  
   # Create a reference to the library in console app:
   dotnet add 'console-xl/console-xl.fsproj' `
   	reference 'library-xl/library-xl.fsproj'
  
  # Restore dependencies and build:
  dotnet restore
  dotnet build
  
  # Execute the console application:
  cd 'console-xl'
  dotnet run
  cd ..
  
   # Create a tests pack for the library:
   dotnet new xunit -lang 'F#' -o 'test-library-xl'
   dotnet add 'test-library-xl/test-library-xl.fsproj' `
   	reference 'library-xl/library-xl.fsproj'
  
  # Restore dependencies and build:
  dotnet restore
  dotnet build
  
  # Run tests:
  cd 'test-library-xl'
  dotnet test
  
  # (optional) Add a dependency to the project:
  dotnet add package YamlDotNet --project 'library-xl'
  # Manually add this to the <PropertyGroup> of the project.
  # <CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>
  
  # (optional) adding a web API
  dotnet new webapi -n 'webapi-xl' --no-https
  ```
  
  Minimal `.gitgnore` for .NET projects build as above:
- ```git
  # .NET binaries and objects
  **/bin/*
  **/obj/*
  
  # Ionide files
  .fake
  ```
- For generating the documentation install `dotnet tool install -g fsdocs-tool` and make sure to enable `GenerateDocumentationFile` in `<PropertyGroup>`; then run `fsdocs build`.