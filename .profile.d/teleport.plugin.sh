# Okta auth into Teleport
alias tshlogin='tsh --proxy https://pluralsight.teleport.sh --auth okta login'


# And an alias to revoke those privileges from yourself whenever you're done.
alias tshrevoke='tsh request drop'

