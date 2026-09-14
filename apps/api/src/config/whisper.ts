import fs from "fs";

export async function transcribeAudioFile(filePath: string): Promise<string> {
  const url = process.env.WHISPER_URL || "http://localhost:9000";
  const buffer = fs.readFileSync(filePath);
  const blob = new Blob([buffer]);
  const formData = new FormData();
  formData.append("audio_file", blob, "audio.m4a");

  const response = await fetch(`${url}/asr?output=json&task=transcribe`, {
    method: "POST",
    body: formData
  });

  if (!response.ok) {
    throw new Error(`Whisper request failed with status ${response.status}`);
  }

  const data = (await response.json()) as { text?: string };
  return (data.text || "").trim();
}
