from flask import Flask, jsonify, request
import requests
from pymongo import MongoClient

app = Flask(__name__)

client = MongoClient('mongodb://localhost:27017/')
db = client['web_scraping_db']
collection = db['web_data']

similarweb_api_key = 'ddf1b2a1c5a44856ae4cdfc5657720d3'

@app.route('/salve_info', methods=['POST'])
def scrape_and_save_info():
    data = request.get_json()
    url = data.get('url')

    if not url:
        return jsonify({'error': 'URL not provided'}), 400

    similarweb_url = f"https://api.similarweb.com/v1/website/{url}/total-traffic-and-engagement?api_key={similarweb_api_key}"
    response = requests.get(similarweb_url)
    similarweb_data = response.json()

    if 'error' in similarweb_data:
        return jsonify({'error': similarweb_data['error']['message']}), 400

    data_entry = {
        'website': url,
        'classification': similarweb_data.get('CategoryRank'),
        'category': similarweb_data.get('Category'),
        'change_in_ranking': similarweb_data.get('ChangeinRank'),
        'average_visit_duration': similarweb_data.get('AverageVisitDuration'),
        'pages_per_visit': similarweb_data.get('PagesPerVisit'),
        'bounce_rate': similarweb_data.get('BounceRate'),
        'top_countries': similarweb_data.get('TopCountryShares'),
        'gender_distribution': similarweb_data.get('GenderDistribution'),
        'age_distribution': similarweb_data.get('AgeDistribution'),
    }
    collection.insert_one(data_entry)

    return jsonify({'result': 'success', 'data': data_entry})

@app.route('/get_info', methods=['POST'])
def get_info():
    data = request.get_json()
    url = data.get('url')

    if not url:
        return jsonify({'error': 'URL not provided'}), 400

    result = collection.find_one({'website': url})

    if result:
        return jsonify({'result': 'success', 'data': result})
    else:
        return jsonify({'error': 'Data not found'}), 404

if __name__ == '__main__':
    app.run(debug=True)
