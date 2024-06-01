import sys
import numpy as np

def analyze_data(file_path):
    try:
        # Чтение данных из ASCII файла
        data = np.loadtxt(file_path)
        
        # Вычисление основных статистических показателей
        mean_val = np.mean(data)
        min_val = np.min(data)
        max_val = np.max(data)
        std_dev = np.std(data)
        
        # Подготовка результатов в виде строки
        results = (
            f"Analysis Results for {file_path}:\n"
            f"Mean: {mean_val}\n"
            f"Min: {min_val}\n"
            f"Max: {max_val}\n"
            f"Standard Deviation: {std_dev}\n"
        )
        
        return results
    except Exception as e:
        return f"Error analyzing data: {e}"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python analyze_data.py <input.ascii>")
        sys.exit(1)

    input_file = sys.argv[1]
    analysis_results = analyze_data(input_file)
    print(analysis_results)
