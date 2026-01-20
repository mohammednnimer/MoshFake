def audio_to_byte_in_txt(input_audio_file, output_text_file):
    # فتح الملف الصوتي وقراءته بشكل ثنائي
    with open(input_audio_file, "rb") as audio_file:
        audio_bytes = audio_file.read()

    # تحويل البيانات الثنائية إلى تمثيل نصي باستخدام hex أو repr
    audio_hex = audio_bytes.hex()  # يمكنك استخدام hex() لتحويلها إلى تمثيل نصي

    # حفظ التمثيل النصي للبيانات الثنائية في ملف نصي
    with open(output_text_file, "w") as text_file:
        text_file.write(audio_hex)

    print(f"تم حفظ البيانات الثنائية للصوت في الملف النصي {output_text_file}")

# الاستخدام
input_audio = "C:\\Users\\HP\\Downloads\\Recording.mp3"  # استبدال هذا بمسار الملف الصوتي
output_file = "audio_output.txt"  # الملف النصي الذي سيتم حفظ البيانات فيه

audio_to_byte_in_txt(input_audio, output_file)
