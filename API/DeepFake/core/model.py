from transformers import pipeline
import librosa
import os
from datasets import Dataset
import torch
from transformers import AutoModelForAudioClassification, AutoFeatureExtractor, Trainer, TrainingArguments

MODEL_ID = "Speech-Arena-2025/DF_Arena_1B_V_1"
MODEL_FALLBACK = "HyperMoon/wav2vec2-base-960h-finetuned-deepfake"
_clf = None

def get_classifier():
    global _clf
    if _clf is None:
        try:
            _clf = pipeline(
                task="antispoofing",
                model=MODEL_ID,  
                device=-1,  \
                trust_remote_code=True
            )
            print(f"Model loaded successfully from {MODEL_ID}")
        except Exception as e:
            print(f"Failed to load {MODEL_ID}: {e}")
            try:
                _clf = pipeline(
                    task="audio-classification",
                    model=MODEL_FALLBACK,  
                    device=-1,
                    trust_remote_code=False
                )
                print(f"Fallback model loaded successfully from {MODEL_FALLBACK}")
            except Exception as e2:
                raise RuntimeError(
                    f"Failed to load model {MODEL_ID} and fallback {MODEL_FALLBACK}: {e} | {e2}"
                )
    return _clf

def load_audio_dataset(human_folder, ai_folders):
    data = []
    for file in os.listdir(human_folder):
        if file.endswith('.wav'):
            data.append({
                "audio": os.path.join(human_folder, file),
                "label": 0  # الصوت البشري
            })
    
    for ai_folder in ai_folders:
        for file in os.listdir(ai_folder):
            if file.endswith('.wav'):
                data.append({
                    "audio": os.path.join(ai_folder, file),
                    "label": 1  
                          })
    
    dataset = Dataset.from_list(data)
    return dataset

def train_model(human_folder, ai_folders, output_dir="./trained_model"):
    dataset = load_audio_dataset(human_folder, ai_folders)
    dataset = dataset.train_test_split(test_size=0.2)
    
    model_name = "facebook/wav2vec2-base"  
    model = AutoModelForAudioClassification.from_pretrained(model_name, num_labels=2)
    feature_extractor = AutoFeatureExtractor.from_pretrained(model_name)
    
    # معالجة البيانات الصوتية
    def preprocess_function(examples):
        audio_arrays = []
        for path in examples["audio"]:
            y, sr = librosa.load(path, sr=16000)
            audio_arrays.append(y)
        
        inputs = feature_extractor(
            audio_arrays, 
            sampling_rate=16000, 
            return_tensors="pt", 
            padding=True,
            truncation=True,
            max_length=16000 * 10  
                )
        inputs["labels"] = examples["label"]
        return inputs
    
    dataset = dataset.map(preprocess_function, batched=True, remove_columns=["audio"])
    
    training_args = TrainingArguments(
        output_dir=output_dir,
        eval_strategy="epoch",
        save_strategy="epoch",
        learning_rate=3e-5,
        per_device_train_batch_size=4,
        per_device_eval_batch_size=4,
        num_train_epochs=3,
        warmup_steps=500,
        logging_steps=10,
    )
    
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        tokenizer=feature_extractor,
    )
    
    trainer.train()
    trainer.save_model(output_dir)
    global MODEL_ID
    MODEL_ID = output_dir  
    print(f"Updated MODEL_ID to {MODEL_ID}")

# لتحميل النموذج وتحضير البيانات
def preload_model():
    get_classifier()

if __name__ == "__main__":
    human_folder = "./Usable Project/OpenAI"
    ai_folders = [
        "./Usable Project/OpenAI",
        "./Usable Project/FlashSpeech",
        "./Usable Project/xTTS",
        "./Usable Project/NaturalSpeech3",
    ]
    
    train_model(human_folder, ai_folders, output_dir="./trained_model")


# from transformers import pipeline, AutoModelForAudioClassification, AutoFeatureExtractor, Trainer, TrainingArguments
# from datasets import Dataset, Audio
# import torch
# import librosa
# import os
# import argparse

# MODEL_ID = "Speech-Arena-2025/DF_Arena_1B_V_1"
# MODEL_FALLBACK = "HyperMoon/wav2vec2-base-960h-finetuned-deepfake"

# _clf = None

# def get_classifier():
#     """Lazy load the audio classification model."""
#     global _clf
#     if _clf is None:
#         try:
#             _clf = pipeline(
#                 task="audio-classification",
#                 model=MODEL_ID,
#                 device=-1,
#                 trust_remote_code=True
#             )
#         except Exception as e:
#             try:
#                 _clf = pipeline(
#                     task="audio-classification",
#                     model=MODEL_FALLBACK,
#                     device=-1,
#                     trust_remote_code=False
#                 )
#             except Exception as e2:
#                 raise RuntimeError(
#                     f"Failed to load model {MODEL_ID} and fallback {MODEL_FALLBACK}: {e} | {e2}"
#                 )
#     return _clf

# def load_audio_dataset(human_folder, ai_folders):
#     """Load audio files from folders and create a dataset."""
#     data = []
    
#     # Load human voice (label 0)
#     for file in os.listdir(human_folder):
#         if file.endswith('.wav'):
#             data.append({
#                 "audio": os.path.join(human_folder, file),
#                 "label": 0  # bonafide
#             })
    
#     # Load AI voices (label 1) from multiple folders
#     for ai_folder in ai_folders:
#         for file in os.listdir(ai_folder):
#             if file.endswith('.wav'):
#                 data.append({
#                     "audio": os.path.join(ai_folder, file),
#                     "label": 1  # spoof
#                 })
    
#     # Create Hugging Face dataset
#     dataset = Dataset.from_list(data)
    
#     return dataset

# def train_model(human_folder, ai_folders, output_dir="./trained_model"):
#     """Train the deepfake detection model."""
#     # Load dataset
#     dataset = load_audio_dataset(human_folder, ai_folders)
    
#     # Split into train/test (80/20)
#     dataset = dataset.train_test_split(test_size=0.2)
    
#     # Load model and feature extractor
#     model_name = "facebook/wav2vec2-base"  # Base model for fine-tuning
#     model = AutoModelForAudioClassification.from_pretrained(model_name, num_labels=2)
#     feature_extractor = AutoFeatureExtractor.from_pretrained(model_name)
    
#     # Preprocessing function
#     def preprocess_function(examples):
#         audio_arrays = []
#         for path in examples["audio"]:
#             y, sr = librosa.load(path, sr=16000)
#             audio_arrays.append(y)
        
#         inputs = feature_extractor(
#             audio_arrays, 
#             sampling_rate=16000, 
#             return_tensors="pt", 
#             padding=True,
#             truncation=True,
#             max_length=16000 * 10  # 10 seconds max
#         )
#         inputs["labels"] = examples["label"]
#         return inputs
    
#     # Apply preprocessing
#     dataset = dataset.map(preprocess_function, batched=True, remove_columns=["audio"])
    
#     # Training arguments
#     training_args = TrainingArguments(
#         output_dir=output_dir,
#         eval_strategy="epoch",
#         save_strategy="epoch",
#         learning_rate=3e-5,
#         per_device_train_batch_size=4,
#         per_device_eval_batch_size=4,
#         num_train_epochs=3,
#         warmup_steps=500,
#         logging_steps=10,
#     )
    
#     # Trainer
#     trainer = Trainer(
#         model=model,
#         args=training_args,
#         train_dataset=dataset["train"],
#         eval_dataset=dataset["test"],
#         tokenizer=feature_extractor,
#     )
    
#     # Train
#     trainer.train()
    
#     # Save model
#     trainer.save_model(output_dir)
#     print(f"Model saved to {output_dir}")
    
#     # Update MODEL_ID to use the trained model
#     global MODEL_ID
#     MODEL_ID = output_dir
#     print(f"Updated MODEL_ID to {MODEL_ID}")

# def preload_model():
#     """Preload model at startup."""
#     get_classifier()

# if __name__ == "__main__":
#     parser = argparse.ArgumentParser(description="Train deepfake detection model")
#     parser.add_argument("--human_folder", required=True, help="Path to folder with human voice WAV files")
#     parser.add_argument("--ai_folders", nargs='+', required=True, help="Paths to folders with AI voice WAV files (space-separated)")
#     parser.add_argument("--output_dir", default="./trained_model", help="Output directory for trained model")
#     args = parser.parse_args()
    
#     train_model(args.human_folder, args.ai_folders, args.output_dir)
