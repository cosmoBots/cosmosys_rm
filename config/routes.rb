# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'cosmosys/:id/menu', :to => 'cosmosys#menu'
get 'cosmosys/:id/tree', :to => 'cosmosys#tree'
get 'cosmosys/:id/treeview', :to => 'cosmosys#treeview'
get 'cosmosys/:id', :to => 'cosmosys#show'
get 'cosmosys/:id/report', :to => 'cosmosys#report'

get 'cosmosys/:id/issues', :to => 'cosmosys_issues#index'


#post 'cosmosys/:id/tree', :to => 'cosmosys#tree'
post 'cosmosys/:id/treeview', :to => 'cosmosys#treeview'
post 'cosmosys/:id/up', :to => 'cosmosys#up'
post 'cosmosys/:id/down', :to => 'cosmosys#down'
post 'cosmosys/:id/report', :to => 'cosmosys#report'
