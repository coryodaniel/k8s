require 'net/http'
require 'json'

# todo cache swagger here ... add to .gitignore
# todo take action/NAME and other things as CLI args to dynamically create the inspection
# rename to inspect.rb

url = 'https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json'
uri = URI(url)
response = Net::HTTP.get(uri);nil
data = JSON.parse(response);nil
paths = data['paths'];nil

paths.reduce([]) do |path_agg, (path, config)|
  config.reduce(path_agg) do |config_agg, (http_method, details)|
    if http_method != "parameters" && details["x-kubernetes-action"] == "connect"
      config_agg.push("#{http_method.upcase}: #{path}")
    end
    
    config_agg
  end
end
