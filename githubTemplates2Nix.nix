{ nixpkgs ? import <nixpkgs>{}
, githubUser ? "countoren"
, githubToken ? ""
, templatePrefix ? "template-"

, curl ? nixpkgs.curl
, jq   ? nixpkgs.jq
}:
let 
  #TODO: synthesize githubUser, templateName
  #TODO: use git ls-remote for getting branches instead of git api
  curlCmd = ''${curl}/bin/curl ${(if githubToken != "" then "-u \"${githubUser}:${githubToken}\"" else "")}'';
  getReposUrl = 
    if githubToken != "" then ''https://api.github.com/user/repos?per_page=1000''
    else ''https://api.github.com/users/${githubUser}/repos?per_page=1000'';

  jqCmd = ''${jq}/bin/jq'';
  ght2nix-repo = nixpkgs.writeShellScript "ght2nix-repo" ''
    while read repo; do
      for line in $(
        ${curlCmd} "https://api.github.com/repos/${githubUser}/$repo/branches?per_page=1000" \
        | ${jqCmd} -r '.[] | "\(.name)@@\(.commit.sha)"' 
      ) ; do

        if [[ $line =~ (^${templatePrefix})([^@]+)@@(.*) ]]; then

        templatePrefix=''${BASH_REMATCH[1]}
        templateName=''${BASH_REMATCH[2]}
        revision=''${BASH_REMATCH[3]}

        echo "    ''${templateName} = tarUrlToDrv { name = \""$templateName"\"; url = \"https://github.com/${githubUser}/$repo/archive/''${revision}.tar.gz\"; };"  

        fi
      done
    done < "''${1:-/dev/stdin}"

'';
in nixpkgs.writeShellScriptBin "ght2nix" ''
    echo '#this file generated by githubTemplates2nix'
    echo 'let tarUrlToDrv = (import ${./.}/templatesUtils.nix).tarUrlToDrv;'
    echo 'in'
    echo '{'
      ${curlCmd} "${getReposUrl}" | ${jqCmd} -r ".[] .name" | ${ght2nix-repo}
    echo '}'
  ''
