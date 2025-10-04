# client.py

import requests
import numpy as np
import argparse
import time
from datetime import datetime

def parse_arguments():
    parser = argparse.ArgumentParser(description="FAISS Index Querying Client")
    parser.add_argument('--server_url', type=str, default='http://localhost:5000/search',
                        help='URL of the FAISS search server')
    parser.add_argument('--dimension', type=int, default=512,
                        help='Dimension of the vectors')
    parser.add_argument('--n_neighbors', type=int, default=10,
                        help='Number of nearest neighbors to search for each query vector')
    parser.add_argument('--n_requests', type=int, default=1000000,
                        help='Number of search requests to send')
    parser.add_argument('--load_index', type=str, help='Path to the new index file to load')

    return parser.parse_args()

def query_server(server_url, dimension, n_neighbors):
    query_vector = np.random.rand(dimension).tolist()
    start_time = time.time()
    response = requests.post(server_url, json={'query': query_vector, 'k': n_neighbors})
    end_time = time.time()
    latency = end_time - start_time

    if response.status_code == 200:
        data = response.json()
        return latency, data['distances'], data['indices']
    else:
        return latency, None, None

def load_index(server_url, index_file_path):
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f'Received request to load new index at {current_time}', flush=True)

    response = requests.post(server_url.replace('/search', '/load'), json={'index_file_path': index_file_path})

    if response.status_code == 200:
        print(f'Successfully loaded index from {index_file_path}', flush=True)
    else:
        print(f'Error loading index from {index_file_path}', flush=True)

    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f'Response received, Time: {current_time}', flush=True)
    print('Response:', response.json(), flush=True)

def main():
    args = parse_arguments()

    if args.load_index:
        load_index(args.server_url, args.load_index)
    else:
        # for _ in range(args.n_requests):
        while True:
            latency, distances, indices = query_server(args.server_url, args.dimension, args.n_neighbors)
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f'Time: {current_time}', flush=True)
            if distances is not None:
                print(f'Latency: {latency:.4f} seconds', flush=True)
                print('Distances:', distances, flush=True)
                print('Indices:', indices, flush=True)
            else:
                print(f'Error: {latency:.4f} seconds', flush=True)

if __name__ == "__main__":
    main()
