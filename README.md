# qwe
Command line bookmarks with autocomplete

Original concept and code by Ólafur Waage but greatly enhanced and rewritten by Michael Mikowski

## Install
Add `qwe.sh` to a folder and call `source qwe.sh` or add `source /your/favorite/folder/qwe.sh` to a file like `.bashrc`

## Usage Example
This example adds `/home/username/my_project` to qwe under the name `work`. Type `qwe work` from anywhere to change the current working directory to that path. Type `qwe work/build` to change to the `build` sub-directory of the named path. Most arguments entries support tab completion including sub-directory searches.

```bash
cd /home/username/my_project
qwe -a work
qwe ~
pwd

qwe work       # use tab completion!
mkdir build
qwe ~
pwd
qwe work/build # use tab completion!
```

## Help

Type `qwe -h` to get the help dialog:
    
```text
qwe                 : Interactive select directory
qwe    <tag>[/path] : Change to directory identified by <tag>[/path]
qwe ~               : Change to user HOME directory
qwe -               : Change to last 'qwe' directory
qwe -a <tag>        : Add a <tag> pointing to current directory
qwe -d <tag>        : Delete <tag>
qwe -h or -?        : Show this help message
qwe -l              : Show sorted list of tags
qwe -p <tag>[/path] : Print the directory identified by <tag>[/path]
qwe -r <tag> <new>  : Rename <tag> with <new> name
qwe -s              : Show tag of current directory
```

## Other Notes

Type `qwe` alone to interactively select a directory. The $HOME directory is parameterized, so the `.qwe.data` file can be shared by multiple users.
