# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'cosmosys/:id/menu', :to => 'cosmosys#menu'
get 'cosmosys/:id/tree', :to => 'cosmosys#tree'
get 'cosmosys/:id', :to => 'cosmosys#show'

post 'cosmosys/:id/tree', :to => 'cosmosys#tree'
post 'cosmosys/:id/up', :to => 'cosmosys#up'
post 'cosmosys/:id/down', :to => 'cosmosys#down'