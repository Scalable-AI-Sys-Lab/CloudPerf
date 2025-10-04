import numpy as np
import faiss
import os

def create_and_store_index_gb(index_size_gb, dimension, index_file_path):
    """
    Create a FAISS index of approximately a given size in GB, and store it on disk.
    """
    bytes_per_vector = 4 * dimension  # 4 bytes per float
    n_vectors = int((index_size_gb * (1024**3)) / bytes_per_vector)  # Total number of vectors to reach the desired index size
    
    index = faiss.IndexFlatL2(dimension)
    batch_size = 10000  # Adjust batch size based on your system's memory capacity
    
    for i in range(0, n_vectors, batch_size):
        vectors = np.random.rand(min(batch_size, n_vectors - i), dimension).astype('float32')
        index.add(vectors)
        print(f"Added batch {i//batch_size + 1}/{(n_vectors + batch_size - 1)//batch_size}")
    
    print(f"Total vectors indexed: {index.ntotal}")

    # Storing the index to disk
    faiss.write_index(index, index_file_path)
    print(f"Index saved to {index_file_path}")

# Example usage
index_size_gb = 20  # Desired index file size in GB
dimension = 512  # Dimension of the vectors
index_file_path = f"faiss_index{index_size_gb}.index"  # Path where the index will be saved
create_and_store_index_gb(index_size_gb, dimension, index_file_path)