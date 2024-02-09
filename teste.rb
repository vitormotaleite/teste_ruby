require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'mongo'
require 'selenium-webdriver'


configure do
  enable :sessions
  set :mongo_uri, 'mongodb://localhost:27017/similarweb_scraper'
end

before do
  content_type 'application/json'
end

post '/salve_info' do
  url = params[:url]
  halt 400, { error: 'URL e necessario' }.to_json unless url

  data = similarweb_scrape(url)
  slavar(url, data)

  { message: 'Data salva com sucesso' }.to_json
end

post '/get_info' do
  url = params[:url]
  halt 400, { error: 'URL e necessario' }.to_json unless url

  data = pegar(url)
  halt 404, { error: 'Data nao encontrada' }.to_json unless data

  data.to_json
end

def similarweb_scrape(url)
  begin
    driver = Selenium::WebDriver.for :chrome
    driver.get("https://www.similarweb.com/website/#{url}")
    sleep(5)
    page = Nokogiri::HTML(driver.page_source)

    classificacao = page.xpath('//*[@id="overview"]/div/div/div/div[3]/div/div[1]/div/p').text.strip
    site = page.xpath('//*[@id="overview"]/div/div/div/div[1]/p[2]').text.strip
    categoria = page.xpath('//*[@id="overview"]/div/div/div/div[5]/div/dl/div[6]/dd/a').text.strip
    mudanca_rank = page.xpath('//*[@id="overview"]/div/div/div/div[3]/div/div[1]/div/span').text.strip
    tempo_medio_visita = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[4]/p[2]').first.text.strip
    paginas_por_visita = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[3]/p[2]').last.text.strip
    taxa_rejeicao = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[2]/p[2]').text.strip
    
    driver.quit

    {
      classificacao: classificacao,
      site: site,
      categoria: categoria,
      mudanca_rank: mudanca_rank,
      tempo_medio_visita: tempo_medio_visita,
      paginas_por_visita: paginas_por_visita,
      taxa_rejeicao: taxa_rejeicao
    }

  rescue StandardError => e
    puts "Erro ao fazer scraping: #{e.message}"
    {
      classificacao: '',
      site: '',
      categoria: '',
      mudanca_rank:'',
      tempo_medio_visita: '',
      paginas_por_visita: '',
      taxa_rejeicao: ''
    }
  end
end

def slavar(url, data)

  cliente = Mongo::Client.new(settings.mongo_uri)
  colecao = cliente[:websites]

  existing_data = colecao.find(url: url).first
  if existing_data
    colecao.update_one({ _id: existing_data['_id'] }, '$set' => data)
  else
    colecao.insert_one(data.merge(url: url))
  end
end

def pegar(url)
  cliente = Mongo::Client.new(settings.mongo_uri)
  colecao = cliente[:websites]

  colecao.find(url: url).first
end
