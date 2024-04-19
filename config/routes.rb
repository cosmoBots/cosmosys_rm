# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'cosmosys/:id/menu', :to => 'cosmosys#menu'
get 'cosmosys/:id/tree', :to => 'cosmosys#tree'
get 'cosmosys/:id/treeview', :to => 'cosmosys#treeview'
get 'cosmosys/:id', :to => 'cosmosys#show'

get 'cosmosys/:id/issues', :to => 'cosmosys_issues#index'
get 'cosmosys_issues/:id/dep_gv', :to => 'cosmosys_issues#dep_gv'
get 'cosmosys_issues/:id/hie_gv', :to => 'cosmosys_issues#hie_gv'
get 'cosmosys/:id/dep_gv', :to => 'cosmosys#dep_gv'
get 'cosmosys/:id/hie_gv', :to => 'cosmosys#hie_gv'

#post 'cosmosys/:id/tree', :to => 'cosmosys#tree'
post 'cosmosys/:id/treeview', :to => 'cosmosys#treeview_commit'
post 'cosmosys/:id/up', :to => 'cosmosys#up'
post 'cosmosys/:id/down', :to => 'cosmosys#down'

post 'cosmosys/convert_to/:format/:project/:swp/:swptitle/:code/:title', :to => 'cosmosys#convert_to'
