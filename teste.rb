require 'sinatra'
require 'nokogiri'
require 'mongo'
require 'rest-client'
require 'json'

mongo_client = Mongo::Client.new(['localhost:27017'], :database => 'scraping_db')
collection = mongo_client[:scraped_data]

def scrape_similarweb(url)
  similarweb_api_url = "https://api.similarweb.com/v1/website/#{URI.escape(url)}/detailed"
  api_key = 'ddf1b2a1c5a44856ae4cdfc5657720d3'

  response = RestClient.get(similarweb_api_url, headers: { 'Api-Key' => api_key })
  data = JSON.parse(response.body)

  detailed_data = {
    'classification' => data['meta']['classification'],
    'site' => data['meta']['site'],
    'category' => data['meta']['category'],
    'ranking_change' => data['meta']['ranking_change'],
    'average_visit_duration' => data['engagement']['average_visit_duration'],
    'pages_per_visit' => data['engagement']['pages_per_visit'],
    'bounce_rate' => data['engagement']['bounce_rate'],
    'top_countries' => data['geography']['top_countries'],
    'gender_distribution' => data['demographics']['gender_distribution'],
    'age_distribution' => data['demographics']['age_distribution']
  }

  detailed_data
end

post '/salve_info' do
  url = params['url']

  halt 400, 'URL inválida' unless url =~ URI::DEFAULT_PARSER.make_regexp

  begin
    similarweb_data = scrape_similarweb(url)
    data = {
      'url' => url,
      'similarweb_data' => similarweb_data
    }

    collection.insert_one(data)

    status 200
    body 'Informações salvas com sucesso'
  rescue => e
    status 500
    body "Erro ao processar a solicitação: #{e.message}"
  end
end

post '/get_info' do
  url = params['url']

  halt 400, 'URL inválida' unless url =~ URI::DEFAULT_PARSER.make_regexp

  data = collection.find('url' => url).first

  if data
    json data
  else
    status 404
    body 'Informações não encontradas no banco de dados'
  end
end
