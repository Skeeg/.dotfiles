# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Wed Sep 20 09:01:29 MST 2023
#

if [ -f /Applications/Privileges.app/Contents/Resources/PrivilegesCLI ]; then
  alias sudo="/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add; sudo "
fi

#sample alias for tsh proxy db
#alias tsh-staging-whatever-db='tsh proxy db --db-name=the_db_name is-bounded-context-aurora --port 5433 --tunnel'
