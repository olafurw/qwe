# qwe
Command line bookmarks with autocomplete

Original concept and code by Ólafur Waage but greatly enhanced and rewritten by Michael Mikowski

**Install:**    
Add `qwe.sh` to a folder and call `source qwe.sh` or add `source /your/favorite/folder/qwe.sh` to a file like `.bashrc`

**Usage Example:**  
Adds `/home/username/my_project` to qwe under the name `work`
Then calling `qwe work` from anywhere will take you there
You can also call `qwe work/build` to go to a subdirectory of the named path (with tab completion)
```
$ cd /home/username/my_project
$ qwe -a work
$ cd ~
$ qwe work
```

**Help:**    
```
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
Use <TAB> to autocomplete <tag>[/path].
'/path' is an optional directory path.
```
