---
title: "Videos"
date: 2026-03-17
layout: "single"
---

<style>
.video-section {
  margin-bottom: 3rem;
}
.video-section h2 {
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
  border-bottom: 2px solid rgba(128,128,128,0.2);
  padding-bottom: 0.5rem;
}
.video-section .section-desc {
  opacity: 0.7;
  margin-bottom: 1.5rem;
  font-size: 0.95rem;
}
.featured-video {
  position: relative;
  width: 100%;
  max-width: 900px;
  margin: 0 auto;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 8px 30px rgba(0,0,0,0.2);
}
.featured-video .video-wrapper {
  position: relative;
  padding-bottom: 56.25%;
  height: 0;
}
.featured-video .video-wrapper iframe {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border: 0;
}
.featured-badge {
  display: inline-block;
  background: linear-gradient(135deg, #ff6b6b, #ee5a24);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  margin-bottom: 0;
}
.playlist-embed {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
  max-width: 900px;
  margin: 0 auto;
}
@media (min-width: 768px) {
  .playlist-embed {
    grid-template-columns: 1fr 1fr;
  }
}
.playlist-card {
  border-radius: 10px;
  overflow: hidden;
  box-shadow: 0 4px 15px rgba(0,0,0,0.12);
  background: #fff;
  transition: transform 0.2s, box-shadow 0.2s;
}
[theme=dark] .playlist-card {
  background: #2a2a2d;
  box-shadow: 0 4px 15px rgba(0,0,0,0.3);
}
.playlist-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 25px rgba(0,0,0,0.2);
}
.playlist-card .video-wrapper {
  position: relative;
  padding-bottom: 56.25%;
  height: 0;
}
.playlist-card .video-wrapper iframe {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border: 0;
}
.playlist-card .card-label {
  padding: 0.75rem 1rem;
  font-size: 0.85rem;
  opacity: 0.7;
  text-align: center;
}
.channel-banner {
  max-width: 900px;
  margin: 0 auto;
  text-align: center;
  padding: 2.5rem 2rem;
  border-radius: 12px;
  background: transparent;
  color: inherit;
}
.channel-banner h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1.4rem;
}
.channel-banner p {
  opacity: 0.8;
  margin-bottom: 1.5rem;
}
.channel-banner .btn-subscribe {
  display: inline-block;
  background: #ff0000;
  color: #fff !important;
  padding: 0.7rem 2rem;
  border-radius: 6px;
  font-weight: 700;
  font-size: 0.95rem;
  text-decoration: none;
  transition: background 0.2s, transform 0.2s;
}
.channel-banner .btn-subscribe:hover {
  background: #cc0000;
  transform: scale(1.05);
}
.channel-banner .btn-subscribe svg {
  vertical-align: middle;
  margin-right: 0.4rem;
}
</style>

<div class="video-section">
  <h2>Featured</h2>
  <p class="section-desc">Building a real-time interactive streaming experience with Amazon IVS.</p>
  <div class="featured-video">
    <span class="featured-badge">★ Featured</span>
    <div class="video-wrapper">
      <iframe src="https://www.youtube-nocookie.com/embed/4Fa_B3LxEVM?rel=0" title="Featured Video" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>
    </div>
  </div>
</div>

<div class="video-section">
  <h2>Amazon IVS Playlist</h2>
  <p class="section-desc">The <a href="https://www.youtube.com/playlist?list=PL5bUlblGfe0LlYN2N55FbJMK4ODo82auM" target="_blank">full series</a> — demos, deep dives, and tutorials on Amazon Interactive Video Service.</p>
  <div class="playlist-embed">
    <div class="playlist-card">
      <div class="video-wrapper">
        <iframe src="https://www.youtube-nocookie.com/embed/videoseries?list=PL5bUlblGfe0LlYN2N55FbJMK4ODo82auM&rel=0" title="Amazon IVS Playlist" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>
      </div>
    </div>
    <div class="playlist-card">
      <div class="video-wrapper">
        <iframe src="https://www.youtube-nocookie.com/embed/videoseries?list=PL5bUlblGfe0LlYN2N55FbJMK4ODo82auM&index=2&rel=0" title="Amazon IVS Playlist (continued)" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>
      </div>
    </div>
  </div>
</div>

<div class="video-section">
  <h2>My Channel</h2>
  <p class="section-desc">More content on my personal YouTube channel — code, cloud, and everything in between.</p>
  <div class="channel-banner">
    <h3>recursive.codes</h3>
    <p>Subscribe for tutorials, live coding, and tech deep dives.</p>
    <a href="https://www.youtube.com/c/recursivecodes?sub_confirmation=1" target="_blank" rel="noopener" class="btn-subscribe">
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="#ffffff"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>
      Subscribe on YouTube
    </a>
  </div>
</div>
