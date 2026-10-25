/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const groqApiKey = defineSecret("GROQ_API_KEY");

exports.generateAiSummary = onCall(
    {secrets: [geminiApiKey, groqApiKey]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in to generate an AI overview.");
      }

      const {title, content, publishedDate, videoUrl} = request.data || {};
      if (
        typeof title !== "string" || !title.trim() || title.length > 1000 ||
        typeof content !== "string" || content.length > 10000 ||
        typeof publishedDate !== "string" || publishedDate.length > 100 ||
        typeof videoUrl !== "string" || videoUrl.length > 500
      ) {
        throw new HttpsError("invalid-argument", "The video details are invalid.");
      }

      let parsedVideoUrl;
      try {
        parsedVideoUrl = new URL(videoUrl);
      } catch (error) {
        throw new HttpsError("invalid-argument", "The video URL is invalid.");
      }
      if (
        parsedVideoUrl.protocol !== "https:" ||
        !["youtube.com", "www.youtube.com", "youtu.be"].includes(parsedVideoUrl.hostname)
      ) {
        throw new HttpsError("invalid-argument", "The video URL must be a YouTube URL.");
      }

      const prompt = `Analyze this news story using only the details provided. Do not invent facts or people. Identify specific people, organizations, countries, or institutions mentioned or directly involved. If none are identifiable, say so. Use these exact plain-text section headings:
DATE & TIME
KEY PEOPLE & ORGANIZATIONS
WHAT IS HAPPENING
LINK OF THE DAY

Under DATE & TIME, mention the date or timeframe of the events. Under KEY PEOPLE & ORGANIZATIONS, list identifiable figures and entities with a brief explanation. Under WHAT IS HAPPENING, give a detailed paragraph covering the central event, actions, and updates. Under LINK OF THE DAY, write "Watch Video Here: ${videoUrl}".

News details:
Title: ${title}
Published: ${publishedDate || "Recently"}
Description: ${content || "No additional text provided."}`;

      try {
        const endpoint = new URL(
            "https://generativelanguage.googleapis.com/v1beta/interactions",
        );

        const response = await fetch(endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": geminiApiKey.value(),
          },
          body: JSON.stringify({
            model: "gemini-3.8-flash",
            input: prompt,
          }),
        });

        if (!response.ok) {
          logger.error("Gemini request returned an error", {status: response.status});
          throw new Error(`Gemini returned HTTP ${response.status}`);
        }

        const result = await response.json();
        const summary = result.output_text?.trim() || result.steps
            ?.filter((step) => step.type === "model_output")
            .flatMap((step) => step.content || [])
            .map((part) => part.text || "")
            .join("")
            .trim();
        if (!summary) {
          throw new Error("Gemini returned no summary text");
        }
        return {summary};
      } catch (error) {
        logger.error("Gemini overview failed; trying Groq fallback");
      }

      let groqKey;
      try {
        groqKey = groqApiKey.value();
      } catch (error) {
        logger.error("Groq fallback secret is unavailable");
        throw new HttpsError("failed-precondition", "The AI fallback is not configured.");
      }
      if (!groqKey) {
        logger.error("Groq fallback is not configured");
        throw new HttpsError("failed-precondition", "The AI fallback is not configured.");
      }

      let groqResponse;
      try {
        groqResponse = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${groqKey}`,
              },
              body: JSON.stringify({
                model: "openai/gpt-oss-120b",
                messages: [{role: "user", content: prompt}],
              }),
            },
        );
      } catch (error) {
        logger.error("Groq request failed to connect");
        throw new HttpsError("unavailable", "The AI overview could not be generated.");
      }

      if (!groqResponse.ok) {
        logger.error("Groq request returned an error", {status: groqResponse.status});
        throw new HttpsError("unavailable", "The AI overview could not be generated.");
      }

      let groqResult;
      try {
        groqResult = await groqResponse.json();
      } catch (error) {
        logger.error("Groq returned an invalid response");
        throw new HttpsError("internal", "The AI overview could not be generated.");
      }

      const summary = groqResult.choices?.[0]?.message?.content?.trim();
      if (!summary) {
        logger.error("Groq returned no summary text");
        throw new HttpsError("internal", "The AI overview could not be generated.");
      }

      return {summary};
    },
);
