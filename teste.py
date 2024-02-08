import requests
from bs4 import BeautifulSoup
from pymongo import MongoClient
from flask import Flask, request, jsonify

app = Flask(__name__)

mongo_client = MongoClient('mongodb://localhost:27017/')
db = mongo_client['similarweb']
collection = db['website_data']

def scrape_similarweb(website_url):
    website_url = input()
    url = f'https://www.similarweb.com/website/{website_url}'
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')

    title = soup.find('title').text
    category = soup.find('span', class_='websiteCategory').text
    global_rank = soup.find('span', class_='globalRank').text
    traffic_country = soup.find('div', class_='trafficCountry')
    top_countries = [country.text for country in traffic_country.find_all('div', class_='countryName')]


    data = {
        'website_url': website_url,
        'title': title,
        'category': category,
        'global_rank': global_rank,
        'top_countries': top_countries,
    }
    return data

@app.route('/salve_info', methods=['POST'])
def save_info():
    website_url = request.json.get('website_url')

    if not website_url:
        return jsonify({'error': 'URL do site ausente na solicitação'}), 400

    data = scrape_similarweb(website_url)

    collection.insert_one(data)

    return jsonify({'message': 'Scraping e armazenamento concluídos com sucesso!'})

@app.route('/get_info', methods=['POST'])
def get_info():
    website_url = request.json.get('website_url')

    if not website_url:
        return jsonify({'error': 'URL do site ausente na solicitação'}), 400

    data = collection.find_one({'website_url': website_url})

    if data:
        return jsonify(data)
    else:
        return jsonify({'error': 'Informações não encontradas no banco de dados'}), 404

if __name__ == '__main__':
    app.run(debug=True)