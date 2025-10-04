# server.py

from flask import Flask, request, jsonify
import faiss
import numpy as np
import os
import setproctitle  # Import the setproctitle module

# Set the process title
setproctitle.setproctitle('vector-server')

app = Flask(__name__)

index = None
index_file_path = './faiss_index20.index'
use_gpu = False  # Set to True if you want to use GPU
dimension = 512

# Load FAISS index
def load_index(index_file_path, use_gpu=False):
    if not os.path.exists(index_file_path):
        print(f"Index file {index_file_path} not found.")
        return None

    index = faiss.read_index(index_file_path)
    if use_gpu:
        gpu_index = faiss.index_cpu_to_gpu(faiss.StandardGpuResources(), 0, index)
        index = gpu_index
        print(f"Index loaded on GPU from {index_file_path}")
    else:
        print(f"Index loaded from {index_file_path} with {index.ntotal} vectors.")

    return index

# Initial index load
index = load_index(index_file_path, use_gpu)

@app.route('/search', methods=['POST'])
def search():
    global index
    query = request.json['query']
    k = int(request.json.get('k', 5))  # Number of nearest neighbors to return

    query_vector = np.array(query).astype('float32').reshape(1, -1)
    distances, indices = index.search(query_vector, k)

    return jsonify({'distances': distances.tolist(), 'indices': indices.tolist()})

@app.route('/load', methods=['POST'])
def load():
    global index, index_file_path, use_gpu
    new_index_file_path = request.json['index_file_path']

    # Load new index
    new_index = load_index(new_index_file_path, use_gpu)
    if new_index is not None:
        index = new_index
        index_file_path = new_index_file_path
        return jsonify({'status': 'success', 'message': f"Index loaded from {new_index_file_path}"})
    else:
        return jsonify({'status': 'error', 'message': f"Failed to load index from {new_index_file_path}"}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)
