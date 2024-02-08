require 'sinatra'
require 'nokogiri'
require 'mongo'
require 'open-uri'

configure do
  set :mongo_uri, 'mongodb://localhost:27017/'
end

before do
  content_type :json
end

post '/salve_info' do
  url = params[:url]
  # Realizar scraping dos dados do SimilarWeb
  scraped_data = scrape_similarweb(url)

  if scraped_data
    # Salvar as informações no MongoDB
    save_to_mongodb(scraped_data)
    { status: 'success', message: 'Informações salvas com sucesso.' }.to_json
  else
    status 500
    { status: 'error', message: 'Erro ao obter informações do SimilarWeb.' }.to_json
  end
end

post '/get_info' do
  url = params[:url]

  # Buscar as informações no banco de dados MongoDB
  stored_data = get_from_mongodb(url)

  if stored_data
    stored_data.to_json
  else
    status 404
    { status: 'error', message: 'Informações não encontradas.' }.to_json
  end
end

def scrape_similarweb(url)
  similarweb_url = "https://www.similarweb.com/website/#{url}"

  begin
    html = open(similarweb_url)
    doc = Nokogiri::HTML(html)
  rescue OpenURI::HTTPError => e
    puts "Erro ao acessar a página: #{e.message}"
    return nil
  end

  data = {}

  data[:url] = url
  data[:classificacao] = doc.at_css('.websiteRanks span').text.strip
  data[:site] = doc.at_css('.websiteHeader-title').text.strip
  data[:categoria] = doc.at_css('.websiteCategory span').text.strip
  data[:mudanca_ranking] = doc.at_css('.rankingInfo-websiteRankChange span').text.strip
  data[:duracao_media_visita] = doc.at_css('.engagementInfo-number:first-child').text.strip
  data[:paginas_por_visita] = doc.at_css('.engagementInfo-number:nth-child(2)').text.strip
  data[:taxa_rejeicao] = doc.at_css('.engagementInfo-number:last-child').text.strip

  # Adicione código para extrair outras informações conforme necessário

  return data
end

def save_to_mongodb(data)
  client = Mongo::Client.new(settings.mongo_uri)
  collection = client[:similarweb_data]
  collection.insert_one(data)
end

def get_from_mongodb(url)
  client = Mongo::Client.new(settings.mongo_uri)
  collection = client[:similarweb_data]
  collection.find(url: url).first
end
