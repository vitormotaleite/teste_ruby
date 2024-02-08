require 'sinatra'
require 'sinatra/json'
require 'nokogiri'
require 'open-uri'
require 'mongo'

configure do
  set :mongo_uri, 'mongodb://localhost:27017/similarweb'
  enable :sessions
end

mongo_client = Mongo::Client.new(settings.mongo_uri)
db = mongo_client.database

collection = db['website_data']

def scrape_similarweb(website_url)
  url = "https://www.similarweb.com/website/#{website_url}"
  doc = Nokogiri::HTML(URI.open(url))

  title = doc.at('title').text
  category = doc.at('.websiteCategory').text
  global_rank = doc.at('.globalRank').text
  traffic_country = doc.at('.trafficCountry')
  top_countries = traffic_country.css('.countryName').map(&:text)

  {
    'website_url' => website_url,
    'title' => title,
    'category' => category,
    'global_rank' => global_rank,
    'top_countries' => top_countries
  }
end

post '/salve_info' do
  website_url = JSON.parse(request.body.read)['website_url']

  if website_url.nil? || website_url.empty?
    status 400
    json(error: 'URL do site ausente na solicitação')
  else
    data = scrape_similarweb(website_url)
    collection.insert_one(data)
    json(message: 'Scraping e armazenamento concluídos com sucesso!')
  end
end

post '/get_info' do
  website_url = JSON.parse(request.body.read)['website_url']

  if website_url.nil? || website_url.empty?
    status 400
    json(error: 'URL do site ausente na solicitação')
  else
    data = collection.find('website_url' => website_url).first
    if data
      json(data)
    else
      status 404
      json(error: 'Informações não encontradas no banco de dados')
    end
  end
end
