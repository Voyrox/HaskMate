# HaskMate: Your Haskell Development Companion

![HaskMate Preview](./Images/img.png)
[![Haskmate Video](./Images/intro.gif)](https://github.com/Voyrox/HaskMate/blob/main/Images/intro.gif)

HaskMate is a Haskell-based project monitoring and automation tool, designed to aid Haskell developers in streamlining their workflow. It continuously watches for changes in your Haskell source files and automatically triggers a rebuild and re-execution of the project whenever a modification is detected.

Crafted for simplicity and efficiency, HaskMate keeps an eye on your file modifications, relieving you from the constant back-and-forth manual building process. It allows developers to focus on what matters the most: writing high-quality Haskell code. With built-in support for smart detection and colorful console outputs, HaskMate is more than just a development tool; it's your mate in Haskell development.

Whether you're prototyping a new function, or debugging a complex piece of logic, HaskMate stands by you, ensuring your changes are instantly built and run, providing immediate feedback on your modifications. It's like having a vigilant companion by your side, dedicated to making your Haskell programming experience smoother and more enjoyable.

Embrace the Haskell way with HaskMate!

## Custom Settings (Optional)

- **Delay**: The time, in microseconds, until the program restarts after a change is made.
- **Ignore**: Specify files to be ignored when changes are detected.
- **Script**: Choose the script to run: `stack`, `ghc`, or `cabal`.
- **Custom Command**: If you prefer a custom command to our preset scripts, enter it here.

```json
{
  "delay": 1000000,
  "ignore": ["./logs.txt", "./src/loop.hs"],
  "script": "stack",
  "cmd": "echo hi && stack build" // Optional field for a custom event command
}
```

## Key Features

- **Automatic File Watch**: HaskMate tracks modifications to your Haskell source files in real-time. Once you save a change, it kicks into action.
- **Instant Build and Re-run**: Upon detecting a file modification, HaskMate triggers a rebuild of your project, followed by an execution of the updated build.
- **Smart Detection**: HaskMate employs an efficient change detection mechanism to ensure no unnecessary builds are run.
- **Colored Console Outputs**: Keep track of what's happening through informative, color-coded console outputs.
- **Settings**: Control what files you want to be monitored in the dir and the delay till it re-starts

## Future Plans

- Ability to customize the file watch pattern to include or exclude specific files or directories.
- Integration with popular Haskell test frameworks for automated testing.


## Installation and Usage

1. **Prerequisites:**
   - Ensure that you have Haskell and Cabal installed on your system. You can download them from the official Haskell website: [https://www.haskell.org/downloads](https://www.haskell.org/downloads).

2. **Clone the Haskmate Repository:**
   - Download the latest version 
   - Click the Green code button
   - Click Download ZIP

3. **Install Haskmate Dependencies:**
   - Run the following command to install the required dependencies using Cabal:
     ```
     cabal install --only-dependencies
     ```

4. **Build Haskmate:**
   - Once the dependencies are installed, build Haskmate by running the following command:
     ```
     stack build
     ```

5. **Install Haskmate:**
   - To install Haskmate on your system, execute the install.ps1 in powershell:
     ```
     Set-ExecutionPolicy RemoteSigned -Scope CurrentUser && install.ps1
     ```

6. **Verify the Installation:**
   - After a successful installation, you can check if Haskmate is working by running the following command:
     ```
     haskmate --version
     ```
   - If the installation was successful, it will display the version number of Haskmate.

## Contributing:

We warmly welcome and appreciate contributions from the community. To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix (`git checkout -b feature/YourFeature`).
3. Make your changes.
4. Commit your changes (`git commit -m 'Add some feature'`).
5. Push to the branch (`git push origin feature/YourFeature`).
6. Open a new Pull Request.

Before submitting your Pull Request, please make sure to follow our coding style and conventions. Your contributions make HaskMate better - thank you!
