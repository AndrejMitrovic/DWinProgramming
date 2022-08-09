module build;

/*
    Build tool to build all samples or individual samples.
*/

import core.thread : Thread, dur;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.functional;
import std.stdio;
import std.string;
import std.path;
import std.file;
import std.process;
import std.parallelism;

extern(C) int kbhit();
extern(C) int getch();

int main(string[] args)
{
    args.popFront;

    foreach (arg; args)
    {
        if (arg.toLower == "clean") cleanOnly = true;
        else if (arg.toLower == "debug") Debug = true;
        else if (arg.toLower == "gdc") compiler = Compiler.GDC;
        else if (arg.toLower == "dmd") compiler = Compiler.DMD;
        else if (arg.toLower == "run") doRun = true;
        else if (arg.toLower == "parallel") parallelBuilding = true;
        else
        if (arg.isFile && arg.extension == ".d")
        {
            soloProject = dirName(arg);
        }
        else
        {
            if (arg.driveName.length)
            {
                if (arg.exists && arg.isDir)
                {
                    soloProject = arg;
                }
                else
                    enforce(0, "Cannot build project in path: \"" ~ arg ~
                              "\". Try wrapping %CD% with quotes when calling build: \"%CD%\"");
            }
        }
    }

    if (compiler == Compiler.GDC)
    {
        auto status = executeShell("perl.exe --help > nul 2>&1 ");

        if (status.status != 0)
        {
            writefln("Error: Couldn't invoke perl.exe: %s. Perl is required to run the "
                ~ "GDMD script, try installing Strawberry Perl: http://strawberryperl.com",
                status.output);
            return 0;
        }
    }

    string[] dirs;
    if (soloProject.length)
    {
        silent = true;
        dirs ~= getSafePath(absolutePath(soloProject));
        string dWinPath = findAbsolutePath(".", "DWinProgramming");
        chdir(dWinPath);
    }
    else
    {
        dirs = getProjectDirs(absolutePath("." ~ `\Samples`));
    }

    if (!cleanOnly)
    {
        checkTools();
        checkWinLib();

        if (!silent)
        {
            //~ writeln("About to build.");

            // @BUG@ The RDMD bundled with DMD 2.053 has input handling bugs,
            // wait for 2.054 to print this out. If you have RDMD from github,
            // you can press 'q' during the build process to force exit.

            //~ writeln("About to build. Press 'q' to stop the build process.");
            //~ Thread.sleep(dur!("seconds")(2));
        }
    }

    try
    {
        buildProjectDirs(dirs, cleanOnly);
        if (soloProject.length && doRun)
            runApp(dirs.front);
    }
    catch (ForcedExitException)
    {
        writeln("\nBuild process halted, about to clean..\n");
        Thread.sleep(dur!("seconds")(1));
        cleanOnly = true;
        buildProjectDirs(dirs, cleanOnly);
    }
    catch (FailedBuildException exc)
    {
        if (soloProject.length)
        {
            writefln("%s failed to build.\n%s", exc.failedMods[0], exc.errorMsgs[0]);
        }
        else
        {
            writefln("\n\n%s projects failed to build:", exc.failedMods.length);
            foreach (i, mod; exc.failedMods)
            {
                writeln(mod, exc.errorMsgs[i]);
            }
        }

        return 1;
    }

    if (!cleanOnly && !silent)
    {
        writeln("\nAll examples succesfully built.");
    }

    return 0;
}

// todo: recover resource compiling code (see first commit)
string[] RCINCLUDES;

bool allExist(string[] paths)
{
    foreach (path; paths)
    {
        if (!path.exists)
            return false;
    }
    return true;
}

void checkWinLib()
{
    win32lib = (compiler == Compiler.DMD)
             ? "dmd_win32.lib"
             : "gdc_win32.lib";

    string buildScript = (compiler == Compiler.DMD)
                    ? "dmd_build.bat"
                    : "gdc_build.bat";

    enforce(win32lib.exists, format("Not found: %s. You have to compile the WindowsAPI bindings "
        ~ "first. Use the %s script in the win32 folder.", win32lib, buildScript));
}

void checkTools()
{
    executeShell("echo int x; > test.h");

    auto res = executeShell("cmd /c htod test.h").status;
    if (res == -1 || res == 1)
    {
        skipHeaderCompile = true;
        writeln("Warning: HTOD missing, won't retranslate .h headers.");
    }

    collectException(std.file.remove("test.h"));
    collectException(std.file.remove("test.d"));

    if (compiler == Compiler.DMD)
    {
        executeShell("echo //void > test.rc");
        string cmd = (compiler == Compiler.DMD)
                   ? "cmd /c rc test.rc > nul"
                   : "cmd /c windres test.rc > nul";

        res = executeShell(cmd).status;
        if (res == -1 || res == 1)
        {
            skipResCompile = true;
            writeln("Warning: RC Compiler not found. Builder will use precompiled resources. "
                ~ "See README for more details.");
        }

        collectException(std.file.remove("test.rc"));
        collectException(std.file.remove("test.res"));
    }

    if (!skipResCompile)
    {
        auto includes = environment.get("RCINCLUDES",
            `C:\Program Files\Microsoft SDKs\Windows\v7.1\Include;C:\Program Files\`
            ~ `Microsoft Visual Studio 10.0\VC\include;C:\Program Files\`
            ~ `Microsoft Visual Studio 10.0\VC\atlmfc\include`).split(";");

        if (includes.allExist)
        {
            RCINCLUDES = includes;
            skipResCompile = false;
        }
        else
            writeln("Won't compile resources.");
    }

    if (skipResCompile)
    {
        writeln("Warning: RC Compiler Include dirs not found. "
            ~ "Builder will will use precompiled resources.");
    }

    writeln();
    Thread.sleep(dur!"seconds"(1));
}

string[] getFilesByExt(string dir, string ext, string ext2 = null)
{
    string[] result;
    foreach (string file; dirEntries(dir, SpanMode.shallow))
    {
        if (file.isFile && (file.extension.toLower == ext || file.extension.toLower == ext2))
        {
            result ~= file;
        }
    }

    return result;
}

__gshared bool Debug;
__gshared bool cleanOnly;
__gshared bool skipHeaderCompile;
__gshared bool skipResCompile;
__gshared bool silent;
__gshared bool doRun;
__gshared bool parallelBuilding;
__gshared string win32lib;
enum Compiler { DMD, GDC }
__gshared Compiler compiler = Compiler.DMD;
string soloProject;

alias reduce!("a ~ ' ' ~ b") flatten;

string[] getProjectDirs(string root)
{
    string[] result;

    if (!isValidPath(root) || !exists(root))
    {
        assert(0, format("Path doesn't exist: %s", root));
    }

    // direntries is not a range in 2.053
    foreach (string dir; dirEntries(root, SpanMode.shallow))
    {
        if (dir.isDir && dir.baseName != "MSDN" && dir.baseName != "Extra2")
        {
            foreach (string subdir; dirEntries(dir, SpanMode.shallow))
            {
                if (subdir.isDir && subdir.baseName != "todo")
                    result ~= subdir;
            }
        }
    }

    return result;
}

bool buildProject(string dir, out string errorMsg)
{
    string appName = absolutePath(dir).baseName;
    string exeName = absolutePath(dir) ~ `\` ~ appName ~ ".exe";
    string LIBPATH = ".";

    string debugFlags = "-IWindowsAPI -I. -version=Unicode -version=WindowsXP -d -g -w -wi";
    string releaseFlags = (compiler == Compiler.DMD)
                        ? "-IWindowsAPI -I. -version=Unicode -version=WindowsXP -d -L-Subsystem:Windows:4"
                        : "-IWindowsAPI -I. -version=Unicode -version=WindowsXP -d -L--subsystem -Lwindows";

    string FLAGS = Debug ? debugFlags : releaseFlags;

    // there's only one resource and header file for each example
    string[] resources;
    string[] headers;

    if (!skipResCompile)
        resources = dir.getFilesByExt(".rc");

    if (!skipHeaderCompile)
        headers = dir.getFilesByExt(".h");

    // have to clean .o files for GCC
    if (compiler == Compiler.GDC)
    {
        executeShell("cmd /c del " ~ absolutePath(dir) ~ `\*.o > nul`);
    }

    if (resources.length)
    {
        string res_cmd;
        final switch (compiler)
        {
            case Compiler.DMD:
            {
                res_cmd = "rc " ~ resources[0].stripExtension ~ ".rc";
                break;
            }

            case Compiler.GDC:
            {
                res_cmd = "windres -i " ~
                          resources[0].stripExtension ~ ".rc" ~
                          " -o " ~
                          resources[0].stripExtension ~ "_res.o";
                break;
            }
        }

        auto pc = executeShell(res_cmd);
        auto output = pc.output;
        auto res = pc.status;

        if (res == -1 || res == 1)
        {
            errorMsg = format("Compiling resource file failed.\nCommand was:\n%s\n\nError was:\n%s",
                res_cmd, output);
            return false;
        }
    }

    // @BUG@ htod can't output via -of or -od, causes multithreading issues.
    // We're distributing precompiled .d files now.
    //~ headers.length && executeShell("htod " ~ headers[0] ~ " " ~ `-IC:\dm\include`);
    //~ headers.length && executeShell("copy resource.d " ~ absolutePath(dir) ~ `\resource.d > nul`);

    // get sources after any .h header files were converted to .d header files
    //~ auto sources   = dir.getFilesByExt(".d", "res");
    auto sources   = dir.getFilesByExt(".d", (compiler == Compiler.DMD)
                                             ? ".res"
                                             : ".o");
    if (sources.length)
    {
        string cmd;

        final switch (compiler)
        {
            case Compiler.DMD:
            {
                cmd = "dmd -vcolumns -m32omf -of" ~ exeName ~
                      " -od" ~ absolutePath(dir) ~ `\` ~
                      " -I" ~ LIBPATH ~ `\` ~
                      " " ~ LIBPATH ~ `\` ~ win32lib ~
                      " " ~ FLAGS ~
                      " " ~ sources.flatten;

                break;
            }

            case Compiler.GDC:
            {
                version(LP_64)
                    enum bitSwitch = "-m64";
                else
                    enum bitSwitch = "-m32";

                cmd = "gdmd.bat " ~ bitSwitch ~ " " ~ "-fignore-unknown-pragmas -mwindows -of"
                      ~ exeName
                      ~ " -od" ~ absolutePath(dir) ~ `\`
                      ~ " -Llibwinmm.a -Llibuxtheme.a -Llibcomctl32.a -Llibwinspool.a "
                      ~ "-Llibws2_32.a -Llibgdi32.a -I" ~ LIBPATH ~ `\`
                      ~ " " ~ LIBPATH ~ `\` ~ win32lib
                      ~ " " ~ FLAGS
                      ~ " " ~ sources.flatten;
                break;
            }
        }

        auto res = executeShell(cmd);
        if (res.status != 0)
        {
            errorMsg = res.output;
            return false;
        }
    }

    return true;
}

void runApp(string dir)
{
    string appName = absolutePath(dir).baseName;
    string exeName = absolutePath(dir) ~ `\` ~ appName ~ ".exe";
    chdir(absolutePath(dir));
    executeShell(exeName);
}

void buildProjectDirs(string[] dirs, bool cleanOnly = false)
{
    // @BUG@ Using chdir in parallel builds wreaks havoc on other threads.
    alias predicate = (dir) => dir.baseName == "EdrTest"
                              || dir.baseName == "ShowBit"
                              || dir.baseName == "StrProg";

    // isn't there an easier way to do this, via predicate or splitter or something..?
    auto serialBuilds = dirs.filter!predicate;
    dirs = dirs.filter!(not!predicate).array;

    if (cleanOnly)
        writeln("Cleaning.. ");

    shared string[] errorMsgs;
    shared string[] failedBuilds;
    void buildDir(string dir)
    {
        if (!cleanOnly && kbhit())
        {
            auto key = cast(dchar)getch();
            stdin.flush();
            enforce(key != 'q', new ForcedExitException);
        }

        if (cleanOnly)
        {
            executeShell("cmd /c del " ~ dir ~ `\` ~ "*.obj > nul");
            executeShell("cmd /c del " ~ dir ~ `\` ~ "*.exe > nul");
        }
        else
        {
            string errorMsg;
            if (!buildProject(dir, /* out */ errorMsg))
            {
                writefln("Failed to build: %s\n%s", dir.relativePath(), errorMsg);
                synchronized errorMsgs ~= errorMsg;
                synchronized failedBuilds ~= dir.relativePath() ~ `\` ~ dir.baseName ~ ".exe";
            }
            else
            {
                if (!silent)
                    writeln("Built ok: " ~ dir.relativePath());
            }
        }
    }

    // GDC has issues when called in parallel (something seems to lock gdc files)
    if (compiler == Compiler.GDC)
        parallelBuilding = false;

    writefln("Building %s samples..\n", dirs.count + serialBuilds.count);

    if (parallelBuilding)
    {
        foreach (dir; parallel(dirs, 1))
            buildDir(dir);
    }
    else
    {
        foreach (dir; dirs)
            buildDir(dir);
    }

    foreach (dir; serialBuilds)
    {
        chdir(absolutePath(dir) ~ `\`);

        if (cleanOnly)
        {
            executeShell("cmd /c del *.obj > nul");
            executeShell("cmd /c del *.o > nul");
            executeShell("cmd /c del *.exe > nul");
            executeShell("cmd /c del *.di  > nul");
            executeShell("cmd /c del *.dll > nul");
            executeShell("cmd /c del *.lib > nul");
        }
        else
        {
            string projScript = (compiler == Compiler.DMD)
                              ? "dmd_build.bat"
                              : "gdc_build.bat";

            string debugFlags = "-I. -version=Unicode -version=WindowsXP -g -w -wi";
            string releaseFlags = (compiler == Compiler.DMD)
                                ? "-I. -version=Unicode -version=WindowsXP -L-Subsystem:Windows:4"
                                : "-I. -version=Unicode -version=WindowsXP -L--subsystem -Lwindows";


            if (projScript.exists)
            {
                auto pc = executeShell(projScript ~ " " ~ (Debug ? "-g" : "-L-Subsystem:Windows"));
                auto output = pc.output;
                auto res = pc.status;

                if (res == 1 || res == -1)
                {
                    failedBuilds ~= absolutePath(".") ~ `\.exe`;
                    errorMsgs ~= output;
                }
            }
        }
    }

    // todo: simpler way to pass shared..?
    enforce(!failedBuilds.length, new FailedBuildException(failedBuilds.to!(string[]),
                                                           errorMsgs.to!(string[])));
}

string findAbsolutePath(string path, string input)
{
    string result;

    foreach (name; path.absolutePath.pathSplitter)
    {
        result = buildPath(result, name);

        if (name == input)
            break;
    }

    return result;
}

/** Remove std.path shenanigans */
string getSafePath(string input)
{
    return input.chomp(`\.`);
}

class ForcedExitException : Exception
{
    this()
    {
        super("");
    }
}

class FailedBuildException : Exception
{
    string[] failedMods;
    string[] errorMsgs;
    this(string[] failedModules, string[] errorMsgs)
    {
        this.failedMods = failedModules;
        this.errorMsgs = errorMsgs;
        super("");
    }
}
