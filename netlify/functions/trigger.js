export async function handler(event) {
  const body = JSON.parse(event.body || "{}");
  const videoURL = body.url;

  const response = await fetch("https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/dispatches", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github.v3+json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      event_type: "yt-download-request",
      client_payload: { url: videoURL }
    }),
  });

  if (response.ok) {
    return {
      statusCode: 200,
      body: JSON.stringify({ ok: true }),
    };
  } else {
    const error = await response.text();
    return {
      statusCode: 500,
      body: JSON.stringify({ ok: false, error }),
    };
  }
}
