require 'sinatra'
require 'nokogiri'
require 'mongo'
require 'rest-client'
require 'json'

mongo = Mongo::Client.new(['localhost:27017'], :database => 'scraping_db')
collection = mongo[:scrapped_data]

def scrape_similarweb(url)
    similarweb_api_url = "https://api.similarweb.com/v1/website/#{URI.escape(url)}/total-traffic-and-engagement"
    api_key = 'ddf1b2a1c5a44856ae4cdfc5657720d3'

    response = RestClient.get(similarweb_api_url, headers: { 'Api-Key' => api_key })
    data = JSON.parse(response.body)

    {
        'visits' => data['visits'],
        'page_views' => data['page_views']
    }
end