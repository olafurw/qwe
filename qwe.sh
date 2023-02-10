#!/bin/bash
#
# Copyright 2013-2022 Ólafur Waage, Michael Mikowski
#
# Name   : qwe.sh
# Purpose: Command line bookmarks with autocomplete
# License: GPL v2
#
# Original concept and code
#   https://github.com/olafurw/olafurw-home/blob/master/tools/qwe.sh
# Inspiration: https://superuser.com/questions/416881
# Also https://stackoverflow.com/questions/7374534
#
# Please add a line to .bashrc to provide this function:
#   source /path/to/qwe.sh
#

## BEGIN UTILITIES {
_qweEscapeRxCharsFn () {
  # Escape special chars for grep -E
  # shellcheck disable=SC2016
  printf '%s' "${1:-}" | sed 's/[.[\*^$()+?{|]/\\&/g';
}

_qweEchoTagDataLine () {
  declare _tag_key _esc_key;
  _tag_key="${1:-}";
  _esc_key="$(_qweEscapeRxCharsFn "${_tag_key}")";
  grep -E "^${_esc_key}"$'\t' "${_qweDataFile}";
}

_qweEchoHeadFn () {
  declare _title _arg_str _count _under_str;
  _arg_str="$*";
  _title="${_qweBasename} Bookmarks";

  if [ -n "${_arg_str}" ]; then
    _title="${_title}: ${_arg_str}";
  fi

  _count=${#_title};
  _under_str=$(printf "%${_count}s" |tr ' ' '=');

  1>&2 cat <<_EOH01

${_title}
${_under_str}
_EOH01
}

_qweEchoStderrFn () {
  1>&2 echo -e "${*:-}";
}

_qweEchoMsgFn () {
  declare _str;
  _str="$*";
  if [ -z "${_str}" ]; then
    _qweEchoStderrFn;
  else
    _qweEchoStderrFn "${_qweBasename}: ${_str}";
  fi
}

_qweEchoConfirmFn () {
  declare _act_str _line_str;
  _act_str="${1:-}";
  _line_str="${2:-}";
  _qweEchoMsgFn "${_act_str} |${_line_str//$'\t'/| }\n  ---";
}

_qweChkTagNameFn () {
  declare _tag_key;
  _tag_key="${1:-}";

  if [ -z "${_tag_key}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Argument required.\n";
    return 1;
  fi

  if ! grep -qE '^[0-9a-zA-Z_.+~-]+$' <<< "${_tag_key}"; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Special chars in tag name |${_tag_key}|";
    _qweEchoMsgFn  "  Use only 0-9, a-Z, _, ., +, ~, or -.\n";
    return 1;
  fi
}

_qweEchoSplitFn () {
  declare _arg_str _esc_home_dir _bit_list _post_str;
  _arg_str="${1:-}";

  # Escape and replace $HOME expansion of '~'
  _esc_home_dir="$(_qweEscapeRxCharsFn "$HOME")";
  # shellcheck disable=SC2001
  _arg_str="$(sed 's|^'"${_esc_home_dir}"'|~|' <<< "${_arg_str}")";

  if grep -qE '/' <<< "${_arg_str}"; then
    IFS='/' read -r -d '' -a _bit_list <<< "${_arg_str}";
    ( IFS='/'; _post_str="${_bit_list[*]:1}";
      printf '%s\n%s' "${_bit_list[0]}" "${_post_str}";
    );
  else
    echo "${_arg_str}";
  fi
}

_qweEchoTagDirFn () {
  declare _tag_key _match_line _tag_dir;
  _tag_key="${1:-}";

  # Handle special '~' home char
  if [ "${_tag_key}" = '~' ]; then
    if [ -n "$HOME" ]; then echo "$HOME"; return; fi
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  'HOME directory is not set.';
    return 1;
  fi

  # Handle special '-' last directory char
  if [ "${_tag_key}" = '-' ]; then
    if [ -n "${_qweLastDirname}" ]; then
      echo "${_qweLastDirname}";
      return;
    fi
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  'No previous qwe directory. Please try again';
    return 1;
  fi

  if ! _qweChkTagNameFn "${_tag_key}"; then return; fi

  _match_line="$(_qweEchoTagDataLine "${_tag_key}")";
  if [ -z "${_match_line}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Tag |${_tag_key}| not found.";
    _qweEchoMsgFn  "Use -l to list; -h or -? for help\n";
    return 1;
  fi

  # shellcheck disable=SC2001
  _tag_dir=$(cut -f2 <<< "${_match_line}");
  echo "${_tag_dir/\$HOME/$HOME}"; # abstract $HOME
}

_qweEchoDirTagFn () {
  declare _search_dir _esc_str _match_line _tag_key;

  _search_dir="${1:-$(pwd)}";
  _search_dir="${_search_dir/$HOME/\$HOME}"; # abstract $HOME
  _esc_str="$(_qweEscapeRxCharsFn "${_search_dir}")";
  _tag_key='';
  _match_line="$(grep -E $'^[^\t]+\t'"${_esc_str}$" "${_qweDataFile}")";

  if [ -n "${_match_line}" ]; then
    _tag_key="$(echo "${_match_line}" |cut -f1)";
  fi

  echo "${_tag_key}";
}

## BEGIN _qweCompReplyFn {
 # Purpose:  Tab completion support
 #
_qweCompReplyFn () {
  declare _arg_str _esc_str _split_list \
    _tag_key _path_str _tag_dir _pwd_dir;

  _arg_str="${2:-}";

  # Handle special tags
  if grep -qE '^[-~]$' <<< "${_arg_str}"; then
    COMPREPLY=( '' "${_arg_str}" ); return;
  fi

  # Handle match without subdirs
  if grep -qv '/' <<<"${_arg_str}"; then
    _esc_str="$(_qweEscapeRxCharsFn "${_arg_str}")";
    IFS=$'\n' read -r -d '' -a COMPREPLY < <(
      grep -E "^${_esc_str}" "${_qweDataFile}" | cut -f1 | sed 's/$/\//g'
    );
    return;
  fi

  # Handle matches with subdirs
  COMPREPLY=();
  IFS=$'\n' read -r -d '' -a _split_list < <(
    _qweEchoSplitFn "${_arg_str}"
  );

  _tag_key="${_split_list[0]}";
  _path_str="${_split_list[1]}";
  _tag_dir="$(_qweEchoTagDirFn "${_tag_key}")";
  if [ -z "${_tag_dir}" ]; then return; fi

  _tag_dir="${_tag_dir/\$HOME/$HOME}"; # abstract $HOME
  _pwd_dir="$(pwd)";
  cd "${_tag_dir}" || return 1;
  for _loop_str in "${_path_str}"*; do
    if [ -d "${_tag_dir}/${_loop_str/}" ]; then
      COMPREPLY+=("${_tag_key}/${_loop_str}/");
    fi
  done

  if [ "${#COMPREPLY}" = '0' ]; then
    COMPREPLY+=("${_arg_str}");
  fi
  cd "${_pwd_dir/\$HOME/$HOME}" || return;
}
## . END _qweCompReplyFn }

## BEGIN _qweReadLineStrFn {
 # Purpose: Custom readline autocomplete
 # I scanned the internet and this does not appear possible using readline.
 # https://stackoverflow.com/questions/4819819
 #
_qweReadLineStrFn () {
  declare _char_str _char_int _char_count _solve_str;

  _solve_str='';
  while true; do
    IFS=$'\n' read -rsn1 _char_str;
    _char_int="$(printf '%d' \'"${_char_str}")";
    # bashsupport disable=BP2002
    case "${_char_int}" in
      # Handle tab
      9 ) _qweCompReplyFn '' "${_solve_str}";
        # Clear line. Move cursor to beginning.
        # https://unix.stackexchange.com/questions/26576
        # https://stackoverflow.com/questions/45065919
        #
        1>&2 printf '\033[1K\033[50D';
        if [ "${#COMPREPLY[@]}" = '1' ]; then
          _solve_str="${COMPREPLY[0]}";
          1>&2 printf '%s' "${_solve_str}";
        else
          ## Begin Print options {
          _solve_str="${COMPREPLY[0]}";
          (( _count="${#_solve_str}" ));
          for _str in "${COMPREPLY[@]}"; do
            1>&2 printf '%s\t' "${_str}";
            ## Begin Solve max matching string {
            while [ "${_count}" -gt 0 ]; do
              _solve_str="${_solve_str:0:$_count}";
              if [[ "${_str}" =~ ^"${_solve_str}" ]]; then break; fi
              (( _count-- ));
            done
            ## . End Solve max matching string }
          done
          1>&2 printf '\n%s' "${_solve_str}";
          ## . End Print options }
        fi
        continue;
      ;;
      # Handle backspace
      127)_char_count="${#_solve_str}";
        if [ "${_char_count}" -gt 0 ]; then
          _solve_str="${_solve_str:0:(($_char_count-1))}"
          1>&2 printf '\b%s\b' ' ';
        fi
        ;;

      # Handle return
      0 ) _qweEchoStderrFn; break;;

      # Handle other keys
      *) 1>&2 printf '%s' "${_char_str}";
        _solve_str+="${_char_str}";
        ;;
    esac
  done
  echo "${_solve_str}";
}
## . END _qweReadLineStrFn }
## . END UTILITIES }

## BEGIN OPTION HANDLERS {
## BEGIN _qweAddTagFn {
 # Purpose: Handler for qwe -a <tag>
 #
_qweAddTagFn () {
  declare _tag_name _match_line _pwd_dir _pwd_tag_key;
  _tag_name="${1:-}";
  if ! _qweChkTagNameFn "${_tag_name}"; then return; fi

  _pwd_dir="$(pwd)";
  _pwd_dir="${_pwd_dir/$HOME/\$HOME}"; # abstract $HOME

  _match_line="$(_qweEchoTagDataLine "${_tag_name}")";
  if [ -n "${_match_line}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Tag |${_tag_name}| already exists.";
    _qweEchoMsgFn  "  Please provide a new, unique tag name.\n";
    return 1;
  fi

  _pwd_tag_key="$(_qweEchoDirTagFn "${_pwd_dir}")";
  if [ -n "${_pwd_tag_key}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "This directory already has the tag |${_pwd_tag_key}|.";
    _qweEchoMsgFn  "  Use -r to rename the tag or -d to delete it.\n";
    return 1;
  fi

  _match_line="${_tag_name}"$'\t'"${_pwd_dir}";
  echo "${_match_line}" >> "${_qweDataFile}" || return;
  _qweEchoConfirmFn 'Add   ' "${_match_line}";
}
## . END _qweAddTagFn }

## BEGIN _qweDeleteTagFn {
 # Purpose: Handler for qwe -d <tag>
 #
_qweDeleteTagFn () {
  declare _tag_name _match_line;
  _tag_name="${1:-}";

  if ! _qweChkTagNameFn "${_tag_name}"; then return; fi

  _match_line="$(_qweEchoTagDataLine "${_tag_name}")";
  if [ -z "$_match_line" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Tag |${_tag_name}| does not exist.";
    _qweEchoMsgFn  "  Use -l to list tags or -h for help.\n";
    return 1;
  fi

  sed -i "/^${_tag_name}\\t/d" "${_qweDataFile}" || return;
  _qweEchoConfirmFn 'Delete' "${_match_line}";
}
## . END _qweDeleteTagFn }

## BEGIN _qweEchoHelpFn {
 # Purpose: Handler for qwe -h
 #
_qweEchoHelpFn () {
  1>&2 cat <<_EOH02
${_qweBasename}                 : Interactive select directory
${_qweBasename}    <tag>[/path] : Change to directory identified by <tag>[/path]
${_qweBasename} ~               : Change to user HOME directory
${_qweBasename} -               : Change to last 'qwe' directory
${_qweBasename} -a <tag>        : Add a <tag> pointing to current directory
${_qweBasename} -d <tag>        : Delete <tag>
${_qweBasename} -h or -?        : Show this help message
${_qweBasename} -l              : Show sorted list of tags
${_qweBasename} -p <tag>[/path] : Print the directory identified by <tag>[/path]
${_qweBasename} -r <tag> <new>  : Rename <tag> with <new> name
${_qweBasename} -s              : Show tag of current directory

Use <TAB> to autocomplete <tag>[/<path>].
_EOH02
}
## . END _qweEchoHelpFn }

## BEGIN _qweEchoTagLinesFn {
 # Purpose: Handler for qwe -l
 #
_qweEchoTagLinesFn () {
  declare _pwd_tag_key _sort_str;
  _pwd_tag_key="$(_qweEchoDirTagFn)";

  _sort_str="$(sort "${_qweDataFile}")";
  _qweEchoStderrFn "TAG\tDIRECTORY
~\tHome: ${HOME:-Not Available}
-\tLast: ${_qweLastDirname:-No Last directory}
${_sort_str}";
  if [ -n "${_pwd_tag_key}" ]; then
    _qweEchoStderrFn "${_pwd_tag_key}\t<= CURRENT DIRECTORY TAG\n";
  fi
}
## . END _qweEchoTagLinesFn }

## BEGIN _qweEchoTagPlusFn {
 # Purpose: Handler for qwe -p <tag>[/path]
 #
_qweEchoTagPlusFn () {
  declare _arg_str _split_list _tag_name _path_str _tag_dir;

  _arg_str="${1:-}";
  IFS=$'\n' read -r -d '' -a _split_list < <(
    _qweEchoSplitFn "${_arg_str}"
  );
  _tag_name="${_split_list[0]}";
  [ "${#_split_list[@]}" -gt 1 ] && _path_str="${_split_list[1]}";

  if _tag_dir="$(_qweEchoTagDirFn "${_tag_name}")"; then
    _tag_dir="${_tag_dir/\$HOME/$HOME}";
  else return; fi

  if [ -n "${_path_str}" ]; then
    echo "${_tag_dir}/${_path_str}" || return;
  else
    echo "${_tag_dir}" || return;
  fi
  return;
}
## . END _qweEchoTagPlusFn }

## BEGIN _qweRenameTagFn {
 # Purpose: Handler for qwe -r <tag>
_qweRenameTagFn () {
  declare _old_key _new_key _match_line;
  _old_key="${1:-}";
  _new_key="${2:-}";

  if ! _qweChkTagNameFn "${_old_key}"; then return; fi
  if ! _qweChkTagNameFn "${_new_key}"; then return; fi

  _match_line="$(_qweEchoTagDataLine "${_old_key}")";
  if [ -z "${_match_line}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "Old Tag |${_old_key}| not found.";
    _qweEchoMsgFn  "  Use -l to list tags or -h for help.\n";
    return 1;
  fi

  _match_line="$(_qweEchoTagDataLine "${_new_key}")";
  if [ -n "${_match_line}" ]; then
    _qweEchoHeadFn 'ERROR';
    _qweEchoMsgFn  "New Tag |${_new_key}| already exists.";
    _qweEchoMsgFn  "  Use -l to list tags or -h for help.\n";
    return 1;
  fi

  if sed -i "s/^${_old_key}"$'\t'"/${_new_key}"$'\t'"/g" \
    "${_qweDataFile}"; then
    _qweEchoMsgFn "Tag |${_old_key}| renamed to |${_new_key}|\n";
    return;
  fi

  _qweEchoHeadFn 'ERROR';
  _qweEchoMsgFn  "Could not rename |${_old_key}|\n"
  return 1;
}
## . END _qweRenameTagFn }

# Option -s: See utilities for qweEchoDirTagFn

## BEGIN _qweCdTagPlusFn {
 # Purpose: Used by handler qweInteractFn
_qweCdTagPlusFn () {
  declare _arg_str _split_list _tag_key _path_str \
    _tag_dir _pwd_str;

  _arg_str="${1:-}";
  IFS=$'\n' read -r -d '' -a _split_list < <(
    _qweEchoSplitFn "${_arg_str}"
  );

  _tag_key="${_split_list[0]}";
  [ "${#_split_list[@]}" -gt 1 ] && _path_str="${_split_list[1]}";

  if _tag_dir="$(_qweEchoTagDirFn "${_tag_key}")"; then
    _tag_dir="${_tag_dir/\$HOME/$HOME}";
  else return; fi

  _pwd_str="$(pwd)";
  if [ -n "${_path_str}" ]; then
    cd "${_tag_dir}/${_path_str}" || return;
  else
    cd "${_tag_dir}" || return;
  fi

  if [ "${_pwd_str}" != "${_qweLastDirname}" ]; then
    _qweLastDirname="${_pwd_str}";
  fi
}
## . END _qweCdTagPlusFn }

## BEGIN _qweInteractFn {
 # Purpose: Handler for qwe <tag>[/path]
_qweInteractFn () {
  declare _reply;

  _qweEchoTagLinesFn;
  _qweEchoStderrFn 'Use <TAB> to autocomplete <tag>[/path].'
  _qweEchoStderrFn 'Enter <tag>[/path], <?> for help, <Enter> to exit.'
  _reply="$(_qweReadLineStrFn)";

  if [ "${_reply}" = '?' ]; then
    _qweEchoHeadFn 'HELP'; _qweEchoHelpFn;
    return;
  fi

  if [ -n "${_reply}" ]; then
    _qweCdTagPlusFn "${_reply}";
    return;
  else
    _qweEchoMsgFn 'Exit';
    _qweEchoMsgFn;
    return;
  fi
}
## . END _qweInteractFn }
## . END OPTION HANDLERS }

## BEGIN qwe main {
qwe () {
  declare _arg1_str _arg2_str _arg3_str;
  _arg1_str="${1:-}";
  _arg2_str="${2:-}";
  _arg3_str="${3:-}";

  ## Begin Process option {
  #  Any option except - consumes arguments and returns
  #
  case "${_arg1_str}" in
    -|-/* ) ;;
    -a ) _qweAddTagFn "${_arg2_str}"; return;;
    -d ) _qweDeleteTagFn "${_arg2_str}"; return;;
    -h|-\? ) _qweEchoHeadFn 'HELP'; _qweEchoHelpFn; return;;
    -l ) _qweEchoHeadFn 'LIST'; _qweEchoTagLinesFn; return;;
    -p ) _qweEchoTagPlusFn "${_arg2_str}"; return;;
    -r ) _qweRenameTagFn "${_arg2_str}" "${_arg3_str}"; return;;
    -s ) _qweEchoDirTagFn; return;;
    -* )
      _qweEchoHeadFn 'ERROR';
      _qweEchoMsgFn  "Invalid option: ${_arg1_str} \n";
      _qweEchoHeadFn 'HELP'; _qweEchoHelpFn; return 1;;
  esac;
  ## . End Process option }

  ## Begin Process input path {
  if [ -n "${_arg1_str}" ]; then
    _qweCdTagPlusFn "$*";
    return;
  else
    _qweEchoHeadFn 'LIST';
    _qweInteractFn;
    return;
  fi
  ## . End Process input path }
}
## . END qwe main }

## BEGIN Prepare autocomplete {
_qweDataFile="${HOME}/.qwe.data";
_qweBasename='qwe';
touch "${_qweDataFile}";
complete -o nospace -F _qweCompReplyFn qwe;
## . END Prepare autocomplete }

