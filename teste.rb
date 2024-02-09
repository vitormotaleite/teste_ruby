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
  halt 400, { error: 'URL is required' }.to_json unless url

  scraped_data = scrape_similarweb(url)
  save_to_mongo(url, scraped_data)

  { message: 'Data saved successfully' }.to_json
end

post '/get_info' do
  url = params[:url]
  halt 400, { error: 'URL is required' }.to_json unless url

  data = retrieve_from_mongo(url)
  halt 404, { error: 'Data not found' }.to_json unless data

  data.to_json
end

def scrape_similarweb(url)
  begin
    driver = Selenium::WebDriver.for :chrome
    driver.get("https://www.similarweb.com/website/#{url}")
    sleep(5)
    page = Nokogiri::HTML(driver.page_source)

    classification = page.xpath('//*[@id="overview"]/div/div/div/div[3]/div/div[1]/div/p').text.strip
    site = page.xpath('//*[@id="overview"]/div/div/div/div[1]/p[2]').text.strip
    category = page.xpath('//*[@id="overview"]/div/div/div/div[5]/div/dl/div[6]/dd/a').text.strip
    ranking_change = page.xpath('//*[@id="overview"]/div/div/div/div[3]/div/div[1]/div/span').text.strip
    average_visit_duration = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[4]/p[2]').first.text.strip
    pages_per_visit = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[3]/p[2]').last.text.strip
    bounce_rate = page.xpath('//*[@id="overview"]/div/div/div/div[4]/div[2]/div[2]/p[2]').text.strip
    
    driver.quit

    {
      classification: classification,
      site: site,
      category: category,
      ranking_change: ranking_change,
      average_visit_duration: average_visit_duration,
      pages_per_visit: pages_per_visit,
      bounce_rate: bounce_rate
    }

  rescue StandardError => e
    puts "Erro ao fazer scraping: #{e.message}"
    {
      classification: '',
      site: '',
      category: '',
      ranking_change:'',
      average_visit_duration: '',
      pages_per_visit: '',
      bounce_rate: ''
    }
  end
end

def save_to_mongo(url, data)

  client = Mongo::Client.new(settings.mongo_uri)
  collection = client[:websites]

  existing_data = collection.find(url: url).first
  if existing_data
    collection.update_one({ _id: existing_data['_id'] }, '$set' => data)
  else
    collection.insert_one(data.merge(url: url))
  end
end

def retrieve_from_mongo(url)
  client = Mongo::Client.new(settings.mongo_uri)
  collection = client[:websites]

  collection.find(url: url).first
end
