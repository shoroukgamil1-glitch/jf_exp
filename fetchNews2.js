// require('dotenv').config();
// const axios = require('axios');
// const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;
// const CHANNEL_ID = "UChqUTb7kYRX8-EiaN3XFrSQ";




// const politicstopics = [ "general geopolitics", "United States politics", "national politics", "Economic Politics", "Artificial Intelligence Politics", "Israelo-Palestinian Conflict Poltics", "Russian-Ukrainian Conflict Politics"];




// const userPicks = ["Artificial Intelligence Politics", "Israelo-Palestinian Conflict Poltics", "Russian-Ukrainian Conflict Politics"];
// async function fetchYoutubeVideos(topic) {
//   try{
//     const oneMonthAgo = new Date(); // a parameter that can help with filtering time is publishedAfterDate, that is in my URL, (not exactly a published at parametere but close enough)
// oneMonthAgo.setDate(oneMonthAgo.getDate() - 30);
// const publishedAfterDate = oneMonthAgo.toISOString(); //this code formats the date into a  year/month/day format, The ISO string format looks like this: 2026-10-02T10:19:10.000Z
//     const searchUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=CHANNELID&q={encodeURIComponent(topic)}&type=video&videoDuration=short&publishedAfter=publishedAfterDate&maxResults=10&order=date&key={YOUTUBE_API_KEY}`;
//     const searchRes =  await axios.get(searchUrl);
//     const searchItems = searchRes.data.items || [];




//     return searchItems;
// } catch (error) {
//     console.error("Error fetching YouTube videos:", error);
//     throw error;
// }
// }




// fetchYoutubeVideos(politicstopics[0])
// .then ((videos) => {
//     console.log(`Fetched ${videos.length} videos for topic: ${userPicks}`);
//     console.log(JSON.stringify(videos, null, 2));
// })
// .catch(console.error);








require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');




const app = express();
app.use(cors());
app.use(express.json());




const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;
const CHANNEL_ID = [
  "UChqUTb7kYRX8-EiaN3XFrSQ","UC52X5wxOL_s5yw0dQk7NtgA", "UCb--64Gl51jIEVE-GLDAVTg","UC6ZFN9Tx6xh-skXCuRHCDpQ"
];




async function fetchYoutubeVideos(topic, CHANNEL_ID) {
 
  try{
    const oneMonthAgo = new Date();
    oneMonthAgo.setDate(oneMonthAgo.getDate() - 30);
    const publishedAfterDate = oneMonthAgo.toISOString();




  const searchUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${CHANNEL_ID}&q=${encodeURIComponent(topic)}&type=video&videoDuration=short&publishedAfter=${publishedAfterDate}&maxResults=10&order=date&key=${YOUTUBE_API_KEY}`;




  const searchRes = await axios.get(searchUrl);
  return searchRes.data.items || [];
} catch (error) {
    console.error(
      `Error fetching for channel ${CHANNEL_ID} and topic ${topic}:`,
      error.message
    );
    throw error;
  }
}








// Endpoint that receives selected categories from Flutter
app.post('/api/fetch-news', async (req, res) => {
  try {
    const { userPicks: selectedTopics } = req.body;




    if (!selectedTopics || !Array.isArray(selectedTopics) || selectedTopics.length === 0) {
      return res.status(400).json({ error: 'No userPicks provided' });
    }
const fetchTasks = CHANNEL_ID.flatMap((channelId) =>
  selectedTopics.map((topic) => fetchYoutubeVideos(topic, channelId))
);


const settledResults = await Promise.allSettled(fetchTasks);
const allVideos = [];


for (const result of settledResults) {
  if (result.status === 'fulfilled') {
    allVideos.push(...result.value);
  } else {
    console.error('A channel/topic fetch failed:', result.reason.message);
  }
}


const seenVideoIds = new Set();
const uniqueVideos = [];


for (const video of allVideos) {
  const videoId = video.id?.videoId || video.id;


  if (videoId && !seenVideoIds.has(videoId)) {
    seenVideoIds.add(videoId);
    uniqueVideos.push(video);
  }
}


uniqueVideos.sort((a, b) =>
  new Date(b.snippet?.publishedAt || 0) -
  new Date(a.snippet?.publishedAt || 0)
);


res.json({
  success: true,
  data: [{ topic: 'All Channels Combined', videos: uniqueVideos }],
});
 } catch (error) {
    console.error("Error fetching YouTube videos:", error.message);
    res.status(500).json({ error: 'Failed to fetch videos' });
  }
});

// another app.post that allows me to send the video details to the backend and get the AI summary back. it takes a title, content, publishedDate, and videoUrl as parameters. it checks if they are valid and then sends them to the Gemini API to get the summary. it returns the summary in the response.

app.post('/api/generate-ai-summary', async (req, res) => {
  const { title, content, publishedDate, videoUrl } = req.body || {};

  if (
    typeof title !== 'string' || !title.trim() ||
    typeof content !== 'string' ||
    typeof publishedDate !== 'string' ||
    typeof videoUrl !== 'string'
  ) {
    return res.status(400).json({ error: 'Invalid video details' });
  }

  const prompt = `Analyze this news story carefully.
Follow these instructions: extract specific people and organizations mentioned;
do not invent facts; use these sections: DATE & TIME, KEY PEOPLE &
ORGANIZATIONS, WHAT IS HAPPENING, and LINK OF THE DAY. MAKE SURE TO INCLUDE THE VIDEO ID AND WHICH CHANNEL THE VIDEO CAME FROM.

Title: ${title}
Date: ${publishedDate || 'Recently'}
Content: ${content || 'No additional text provided.'}
Video URL: ${videoUrl}`;

  try {
    const response = await axios.post(
      'https://generativelanguage.googleapis.com/v1beta/interactions',
      {
        model: 'gemini-3.8-flash',
        input: prompt,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': process.env.GEMINI_API_KEY,
        },
      }
    );

    const summary = response.data.output_text?.trim() ||
      response.data.steps
        ?.filter((step) => step.type === 'model_output')
        .flatMap((step) => step.content || [])
        .map((part) => part.text || '')
        .join('')
        .trim();

    if (!summary) {
      throw new Error('Gemini returned no summary');
    }

    return res.json({ summary });
  } catch (error) {
    console.error('Gemini overview failed; trying Groq fallback:', {
      status: error.response?.status,
      message: error.response?.data?.error?.message || error.message,
    });
  }

  if (!process.env.GROQ_API_KEY) {
    console.error('Groq fallback is not configured.');
    return res.status(502).json({ error: 'Could not generate overview' });
  }

  try {
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'openai/gpt-oss-120b',
        messages: [{ role: 'user', content: prompt }],
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
        },
      }
    );

    const summary = response.data.choices?.[0]?.message?.content?.trim();
    if (!summary) {
      throw new Error('Groq returned no summary');
    }

    return res.json({ summary });
  } catch (error) {
    console.error('Groq overview request failed:', {
      status: error.response?.status,
      message: error.response?.data?.error?.message || error.message,
    });
    return res.status(502).json({ error: 'Could not generate overview' });
  }
});
   






const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
});




const politicstopics = [ "general geopolitics", "United States politics", "national politics", "Economic Politics", "Artificial Intelligence Politics", "Israelo-Palestinian Conflict Poltics", "Russian-Ukrainian Conflict Politics"];




const userPicks = ["Artificial Intelligence Politics", "Israelo-Palestinian Conflict Poltics", "Russian-Ukrainian Conflict Politics"];
async function fetchYoutubeVideos(topic, CHANNEL_ID) {
  try{
    const oneMonthAgo = new Date(); // a parameter that can help with filtering time is publishedAfterDate, that is in my URL, (not exactly a published at parametere but close enough)
oneMonthAgo.setDate(oneMonthAgo.getDate() - 30);
const publishedAfterDate = oneMonthAgo.toISOString(); //this code formats the date into a  year/month/day format, The ISO string format looks like this: 2026-10-02T10:19:10.000Z
    const searchUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${CHANNEL_ID}&q=${encodeURIComponent(topic)}&type=video&videoDuration=short&publishedAfter=${publishedAfterDate}&maxResults=10&order=date&key=${YOUTUBE_API_KEY}`;
    const searchRes =  await axios.get(searchUrl);
    const searchItems = searchRes.data.items || [];




    return searchItems;
} catch (error) {
    console.error("Error fetching YouTube videos:", error);
    throw error;
}
}




fetchYoutubeVideos(politicstopics[0], CHANNEL_ID)
.then ((videos) => {
    console.log(`Fetched ${videos.length} videos for topic: ${userPicks}`);
    console.log(JSON.stringify(videos, null, 2));
})
.catch(console.error);




//so now i make a new array of videos, using their videoID to indicate whether or not they
//have been seen before. if they have, they are not added to the new array. if they have not been seen before, they are added to the new array.









