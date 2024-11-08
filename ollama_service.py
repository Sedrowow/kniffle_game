from flask import Flask, request, jsonify
import requests  # Assuming OLLAMA has an API you can interact with

app = Flask(__name__)

@app.route('/ollama', methods=['POST'])
def ollama():
    data = request.get_json()
    prompt = data.get('prompt', '')
    # Send the prompt to OLLAMA LLM and get the response
    # You need to implement this based on how OLLAMA's API works
    response_text = send_prompt_to_ollama(prompt)
    return jsonify({'response': response_text})

@app.route('/ollama/health', methods=['GET'])
def health():
    return 'OK', 200
def send_prompt_to_ollama(prompt):
        # Replace 'OLLAMA_API_ENDPOINT' with the actual endpoint of the OLLAMA API
        OLLAMA_API_ENDPOINT = 'https://api.ollama.ai/generate'
        
        # Replace 'YOUR_API_KEY' with your actual API key for OLLAMA
        headers = {
            'Authorization': 'Bearer YOUR_API_KEY',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'prompt': prompt
        }
        
        try:
            response = requests.post(OLLAMA_API_ENDPOINT, headers=headers, json=payload)
            response.raise_for_status()  # Raise an error for bad status codes
            response_data = response.json()
            return response_data.get('generated_text', 'No response text found.')
        except requests.exceptions.RequestException as e:
            return f'An error occurred: {e}'

if __name__ == '__main__':
    app.run(port=5000)
