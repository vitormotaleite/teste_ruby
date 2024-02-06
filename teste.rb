require 'sinatra'
require 'nokogiri'
require 'mongo'
require 'rest-client'
require 'json'

mongo_client = Mongo::Client.new(['localhost:27017'], :database => 'scraping_db')
collection = mongo_client[:scraped_data]

def scrape_similarweb(url)
  similarweb_api_url = "https://api.similarweb.com/v1/website/#{URI.escape(url)}/total-traffic-and-engagement"
  api_key = 'SUA_CHAVE_DE_API_SIMILARWEB'

  response = RestClient.get(similarweb_api_url, headers: { 'Api-Key' => api_key })
  data = JSON.parse(response.body)

  {
    'visits' => data['visits'],
    'page_views' => data['page_views']
  }
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
