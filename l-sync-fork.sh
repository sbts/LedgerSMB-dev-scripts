#!/bin/bash

#If a repo already has an upstream remote URL this variable will be overridden
Upstream='https://github.com/ledgersmb/LedgerSMB.git'

Dir=`git rev-parse --show-toplevel`

if ! [[ -d "$Dir" ]]; then
    cat <<-EOF
	usage: $0 directory
	
	Where directory is your local copy of a fork of LedgerSMB
	
	If directory is not provided and
	    git rev-parse --show-toplevel
	correctly returns the top of the repository that will be used.
	
EOF
    exit 1;
fi

cd `readlink -f "${Dir}"`


Error() {
    cat <<-EOF
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%% ERROR %% ERROR %% ERROR %% ERROR %% ERROR %% ERROR %%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%                                                    %%$(printf "\r%% %s" "$1")
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	Be aware 
	    - I may have left changes stashed via "git stash"
	    - You may not be in the expected branch.
	        run "git status" to confirm"
	
EOF
    exit 1
}

if ! [[ -r LedgerSMB.pm ]] && ! [[ -r lib/LedgerSMB.pm ]] ; then
    Error "Not a LedgerSMB repository"
fi

## lets get the current upstream remote URL if it's available
#while read L; do
#    if [[ $L =~ upstream.*(push) ]]; then
#        L="${L/upstream[  ]/}";
#        Upstream="${L%[      ](push*}";
#        echo "Upstream URL set to $Upstream";
#    fi
#done < <(git remote -v)
#if [[ -z $Upstream ]]; then
#    Error "No upstream URL set for this repository"
#fi

AvailableRemotes=`git remote -v`
if ! [[ $AvailableRemotes =~ $Upstream ]]; then
    if  [[ $AvailableRemotes =~ upstream ]]; then
        echo -e "$AvailableRemotes\n\n"
        printf "Can't Add Upstream Remote\n\t%s\n" "$Upstream"
        Error "Another Upstream already exists."
    fi

    printf "Adding Upstream Remote\n\t%s\n\n" "$Upstream"
    git remote add upstream "$Upstream"
fi

CurrentBranch=`git rev-parse --abbrev-ref HEAD`

# using stash create may cause issues if we fail during the other git operations, 
# as when we re-run this script we won't know what the stashID is 
# so won't be able to revert to the original state of the repo
# at least if we use "stash save --all" a manual pop would be enough to restore state
#stash=`git stash create`
unset stash

echo "Stashing any uncommited changes"
git stash save --all "automatic stash while running 'sync-fork.sh'"

echo "fetching upstream"
git fetch upstream || Error "Fetching Upstream."

echo "syncing master"
git checkout master || Error "Checking out Master."
git merge upstream/master || Error "Merging upstream/master with local /master" || Error "Merging master";
git push

echo "syncing 1.5"
git checkout 1.5 || Error "Checking out 1.5."
git merge upstream/1.5 || Error "Merging upstream/1.5 with local /1.5" || Error "Merging 1.5";
git push

echo "returning you to your working branch"
echo "checking out $CurrentBranch"
git checkout "$CurrentBranch" || Error "Checking out $CurrentBranch."

echo "Popping any edits we stashed"
git stash pop $stash

cat <<EOF

    Don't forget:
      Syncing your fork only updates your local copy of the repository.
      To update your fork on GitHub, you must push your changes.
      using
        git push

    If you are working on a branch then you will also need to do something like
        git merge upstream/master
      or
        git merge upstream/1.5
    Both of which have already been done for you.

EOF


