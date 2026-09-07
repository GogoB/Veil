/* UI study only: all content and interactions live in this browser tab. */
'use strict';

const $ = (selector, scope = document) => scope.querySelector(selector);
const $$ = (selector, scope = document) => [...scope.querySelectorAll(selector)];
const escapeHTML = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const icon = (name, extra = '') => `<svg class="icon ${extra}" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const initialDraft = 'I walked the long way home just to finish an album. No regrets.';
const aliases = ['quiet frequency', 'low orbit', 'paper satellite', 'soft eclipse', 'distant signal', 'silver hour'];
const sigils = ['sigil', 'sigil2', 'sigil3'];
const state = {
  feed: 'discover', topic: 'All', identity: 'anonymous', mode: 'generated', aliasIndex: 0,
  sensitive: false, images: [], pendingImages: 0, draftVersion: 0,
  hidden: new Set(), muted: new Set(), liked: new Set(), comments: new Map(), replyIdentities: new Map(),
  posts: [
    {id:'p1', name:'soft static', anonymous:true, sigil:'sigil2', time:'12m', topic:'After hours',
      text:'Anyone else feel more like themselves after the city goes quiet?', likes:128, replies:24, expiry:'23h left'},
    {id:'p2', name:'noor', anonymous:false, followed:true, time:'28m', topic:'Architecture',
      text:'Some buildings feel like a pause button.', images:['assets/concrete.jpg'], imageAlt:'Monumental concrete columns seen from below in black and white', credit:true, likes:86, replies:9},
    {id:'p3', name:'low orbit', anonymous:true, sigil:'sigil3', time:'41m', topic:'Music',
      text:'An album you wish you could hear for the first time again. I’ll start: Untrue.', likes:204, replies:67, expiry:'6d left'},
    {id:'p4', name:'form & field', anonymous:false, followed:true, time:'1h', topic:'Architecture',
      text:'A good public space lets you be alone without feeling lonely.', likes:53, replies:8}
  ]
};
let toastTimer;
let sheetFocus;
let activePost;

function notify(message) {
  const toast = $('#toast');
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.hidden = false;
  toastTimer = setTimeout(() => { toast.hidden = true; }, 4000);
}

function actorMarkup(post) {
  const mark = post.anonymous ? icon(post.sigil || 'sigil') : (post.name === 'noor' ? 'n.' : 'f.');
  return `<span class="avatar ${post.anonymous ? '' : 'profile-avatar'}">${mark}</span>`;
}

function postMarkup(post) {
  const liked = state.liked.has(post.id);
  const actorLabel = post.name || 'anonymous participant';
  const sigilOnly = post.anonymous && post.presentation === 'sigil';
  const extraComments = (state.comments.get(post.id) || []).length;
  const images = post.images || [];
  let media = '';
  if (images.length) {
    media = `<div class="picture-stack">${images.map((url, index) => `<img class="post-picture" src="${escapeHTML(url)}" alt="${escapeHTML(post.imageAlt || `Attached image ${index + 1}`)}" ${post.credit ? '' : 'loading="lazy"'}>`).join('')}</div>`;
    if (post.sensitive) media = `<div class="sensitive-media">${media}<button class="reveal-media" data-action="reveal" data-id="${post.id}">Sensitive content · Tap to reveal</button></div>`;
    if (post.credit) media = `<figure>${media}<figcaption>Photo: Osman Rana / Unsplash</figcaption></figure>`;
  }
  return `<article class="post" data-post="${post.id}" aria-label="Post by ${escapeHTML(actorLabel)}">
    <div class="post-head">${actorMarkup(post)}<div class="post-byline"><div class="post-author-line">${sigilOnly ? '' : `<span class="post-author">${escapeHTML(post.name)}</span>`}${post.anonymous ? '<span class="veil-label">VEILED</span>' : ''}</div><span class="post-meta">${post.anonymous ? (sigilOnly ? 'Thread sigil' : 'Thread alias') : '@' + escapeHTML(post.name.replace(/\W/g, ''))} <span aria-hidden="true">·</span> ${escapeHTML(post.time)}</span></div><button class="icon-button post-more" data-action="more" data-id="${post.id}" aria-label="More options for ${escapeHTML(actorLabel)}’s post">${icon('dots')}</button></div>
    ${post.text ? `<p class="post-text">${escapeHTML(post.text)}</p>` : ''}${media}
    ${post.topic ? `<button class="post-topic" data-action="topic" data-topic="${escapeHTML(post.topic)}">${escapeHTML(post.topic)}</button>` : ''}
    <div class="post-footer"><button class="post-action" data-action="like" data-id="${post.id}" aria-label="Like ${escapeHTML(actorLabel)}’s post" aria-pressed="${liked}">${icon('heart')}<span>${post.likes + (liked ? 1 : 0)}</span></button><button class="post-action" data-action="comments" data-id="${post.id}" aria-label="Open replies to ${escapeHTML(actorLabel)}’s post">${icon('chat')}<span>${post.replies + extraComments}</span></button>${post.expiry ? `<span class="expiry-label">${icon('clock')}${escapeHTML(post.expiry)}</span>` : ''}<button class="post-action" data-action="share" data-id="${post.id}" aria-label="Share ${escapeHTML(actorLabel)}’s post">${icon('arrow')}</button></div>
  </article>`;
}

function visiblePosts() {
  return state.posts.filter(post => !state.hidden.has(post.id) && !state.muted.has(post.topic)
    && (state.feed === 'discover' || (!post.anonymous && post.followed))
    && (state.topic === 'All' || post.topic === state.topic));
}

function renderFeed() {
  const posts = visiblePosts();
  $('#feed').innerHTML = posts.length ? posts.map(postMarkup).join('') : '<p class="empty-feed">A little quiet here.<br>Try another topic or switch to Discover.</p>';
  $('#feed').setAttribute('aria-labelledby', `tab-${state.feed}`);
  $$('[data-feed]').forEach(button => button.setAttribute('aria-selected', button.dataset.feed === state.feed));
  $$('.topic-list [data-topic]').forEach(button => button.setAttribute('aria-pressed', button.dataset.topic === state.topic));
}

function setTopic(topic) {
  state.topic = topic;
  renderFeed();
  $('#feed').scrollTop = 0;
}

function presentSheet(title, content) {
  sheetFocus = document.activeElement;
  $('#sheet-title').textContent = title;
  $('#sheet-content').innerHTML = content;
  $('#sheet-backdrop').hidden = false;
  $('#detail-sheet').hidden = false;
  // Inert the rest of this phone while its sheet is open.
  [...$('#discover-phone').children].filter(el => !['detail-sheet','sheet-backdrop'].includes(el.id)).forEach(el => { el.inert = true; });
  $('#close-sheet').focus({preventScroll:true});
}

function closeSheet() {
  $('#sheet-backdrop').hidden = true;
  $('#detail-sheet').hidden = true;
  [...$('#discover-phone').children].forEach(el => { el.inert = false; });
  if (sheetFocus && sheetFocus.isConnected) sheetFocus.focus({preventScroll:true});
  activePost = undefined;
}

function showComments(post) {
  activePost = post.id;
  if (!state.replyIdentities.has(post.id)) {
    const names = ['paper moon', 'quiet tide', 'hollow star', 'silver echo', 'faint outline'];
    const index = state.replyIdentities.size;
    state.replyIdentities.set(post.id, `${names[index % names.length]}${index >= names.length ? ' ' + Math.floor(index / names.length + 1) : ''}`);
  }
  const replyIdentity = state.replyIdentities.get(post.id);
  const sample = post.id === 'p1' ? [{name:'night window',text:'Less noise outside. Less noise in my head.',time:'8m'},{name:'soft static · OP',text:'Exactly this. Everything has a little more room.',time:'6m'}] : [];
  const comments = [...sample, ...(state.comments.get(post.id) || [])];
  const commentMarkup = comments.map(comment => `<div class="comment"><strong>${escapeHTML(comment.name)}</strong><p>${escapeHTML(comment.text)}</p><span>${escapeHTML(comment.time)}</span></div>`).join('');
  presentSheet('The conversation', `<p class="sheet-copy">${escapeHTML(post.text)}</p><div id="comments-list">${commentMarkup || '<p class="sheet-copy">Leave a little something.</p>'}</div><form class="reply-form" id="reply-form"><input class="reply-input" id="reply-text" aria-label="Your reply" placeholder="Add a thought…" maxlength="2000" required><button aria-label="Send reply" type="submit">${icon('arrow')}</button></form><p class="identity-note">Replying as ${escapeHTML(replyIdentity)} · anonymous in this thread.</p>`);
  activePost = post.id;
  $('#reply-form').addEventListener('submit', event => {
    event.preventDefault();
    const text = $('#reply-text').value.trim();
    if (!text) return;
    const replies = state.comments.get(post.id) || [];
    replies.push({name:replyIdentity, text, time:'Just now'});
    state.comments.set(post.id, replies);
    renderFeed();
    showComments(post);
    $('#reply-text').focus();
  });
}

function showSearch() {
  presentSheet('Find your people.', '<p class="sheet-copy">Public profiles, posts, and topics.</p><input id="search-query" class="search-input" type="search" aria-label="Search public content" placeholder="Try architecture or music…"><div id="search-results" class="search-results"></div>');
  function results() {
    const query = $('#search-query').value.trim().toLowerCase();
    // Thread aliases are intentionally excluded from searchable fields.
    const posts = state.posts.filter(post => !state.hidden.has(post.id) && !state.muted.has(post.topic) &&
      [post.text, post.topic, ...(post.anonymous ? [] : [post.name])].join(' ').toLowerCase().includes(query));
    $('#search-results').innerHTML = posts.length ? posts.map(post => `<div class="search-result"><strong>${escapeHTML(post.anonymous ? 'Anonymous post' : post.name)}</strong><p>${escapeHTML(post.text)}</p><span>${escapeHTML(post.topic)}</span></div>`).join('') : '<p class="sheet-copy">No public results. Try a different word.</p>';
  }
  $('#search-query').addEventListener('input', results);
  results();
  $('#search-query').focus();
}

function showActivity() {
  const posts = state.posts.filter(post => post.mine && post.anonymous);
  presentSheet('Veiled Activity', '<p class="sheet-copy">Your anonymous posts, together in one private space.</p>' + (posts.length ? posts.map(postMarkup).join('') : `<div class="sheet-empty">${icon('sigil')}<h3>A space just for you.</h3><p>Your anonymous posts will appear here.<br>Share your first thought from the composer.</p></div>`));
}

function handlePostAction(event) {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  const post = state.posts.find(item => item.id === button.dataset.id);
  if (button.dataset.action === 'topic') { closeSheet(); setTopic(button.dataset.topic); return; }
  if (!post) return;
  if (button.dataset.action === 'like') {
    state.liked.has(post.id) ? state.liked.delete(post.id) : state.liked.add(post.id);
    // Update visible copies in place to preserve scroll and keyboard focus.
    $$(`[data-action="like"][data-id="${post.id}"]`).forEach(copy => {
      copy.setAttribute('aria-pressed', state.liked.has(post.id));
      $('span', copy).textContent = post.likes + (state.liked.has(post.id) ? 1 : 0);
    });
  }
  if (button.dataset.action === 'comments') showComments(post);
  if (button.dataset.action === 'reveal') {
    button.parentElement.classList.remove('sensitive-media');
    button.remove();
  }
  if (button.dataset.action === 'more') {
    presentSheet('Your feed. Your call.', `<p class="sheet-copy">Make a little more room for what you want to see.</p><button class="sheet-button" id="hide-post">Hide this post${icon('close')}</button>${post.topic ? `<button class="sheet-button" id="mute-topic">Mute ${escapeHTML(post.topic)}${icon('chevron')}</button>` : ''}`);
    $('#hide-post').addEventListener('click', () => { state.hidden.add(post.id); closeSheet(); renderFeed(); notify('Post hidden in this preview.'); });
    if ($('#mute-topic')) $('#mute-topic').addEventListener('click', () => { state.muted.add(post.topic); closeSheet(); renderFeed(); notify(`${post.topic} muted in this preview.`); });
  }
  if (button.dataset.action === 'share') {
    presentSheet('Pass the thought on.', `<p class="sheet-copy">${escapeHTML(post.text)}</p><button class="sheet-button" id="copy-post">Copy post text${icon('arrow')}</button>`);
    $('#copy-post').addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(post.text); notify('Post text copied.'); closeSheet(); }
      catch { notify('Clipboard unavailable. You can select the text above to copy it.'); }
    });
  }
}

function currentAlias() {
  if (state.identity === 'profile') return 'noor';
  if (state.mode === 'sigil') return 'Unnamed';
  if (state.mode === 'custom') return $('#custom-alias').value.trim() || 'your chosen alias';
  return aliases[state.aliasIndex % aliases.length];
}

function currentSigil() { return sigils[state.aliasIndex % sigils.length]; }

function renderIdentity() {
  const anonymous = state.identity === 'anonymous';
  $$('[data-identity]').forEach(button => button.setAttribute('aria-pressed', button.dataset.identity === state.identity));
  $$('[data-mode]').forEach(button => button.setAttribute('aria-pressed', button.dataset.mode === state.mode));
  $('#anonymous-options').hidden = !anonymous;
  $('#profile-identity').hidden = anonymous;
  $('#identity-title').innerHTML = anonymous ? 'Behind<br>the veil.' : 'In your<br>own name.';
  $('#large-sigil use').setAttribute('href', `#i-${anonymous ? currentSigil() : 'person'}`);
  $('#alias-icon use').setAttribute('href', `#i-${currentSigil()}`);
  $('#alias-name').hidden = state.mode === 'custom';
  $('#custom-alias').hidden = state.mode !== 'custom';
  $('#regenerate-alias').setAttribute('aria-label', state.mode === 'generated' ? 'Generate a new alias and sigil' : 'Generate a new sigil');
  $('#alias-name').textContent = currentAlias();
  $('#alias-description').textContent = state.mode === 'sigil' ? 'YOUR SIGIL IN THIS THREAD' : 'IN THIS THREAD, YOU’RE';
  $('#identity-note').innerHTML = `<span class="note-dot"></span><span>${anonymous ? 'This post won’t appear on your public profile.' : 'This post appears on your public profile.'}</span>`;
  $('#posting-as').innerHTML = `Posting ${state.mode === 'sigil' && anonymous ? 'with ' : 'as '}<strong>${escapeHTML(state.mode === 'sigil' && anonymous ? 'a thread-only sigil' : currentAlias())}</strong>`;
  $('.composer-bottom > .icon use').setAttribute('href', `#i-${anonymous ? currentSigil() : 'person'}`);
  $('#form-error').hidden = true;
}

function updateDraft() {
  const length = Array.from($('#post-text').value).length;
  $('#character-count').textContent = `${length.toLocaleString('en-US')} / 2,000`;
  $('#publish').disabled = state.pendingImages > 0 || (!$('#post-text').value.trim() && state.images.length === 0);
}

function formError(message) {
  $('#form-error').textContent = message;
  $('#form-error').hidden = false;
  $('#form-error').scrollIntoView({block:'nearest'});
}

function renderImages() {
  $('#image-previews').innerHTML = state.images.map((image, index) => `<div class="image-preview"><img src="${image.url}" alt="Attachment ${index + 1}"><button data-remove-image="${index}" aria-label="Remove attachment ${index + 1}">${icon('close')}</button></div>`).join('');
  updateDraft();
}

async function attachImages(files) {
  if (state.images.length + state.pendingImages + files.length > 4) { formError('You can add up to four images.'); return; }
  const draftVersion = state.draftVersion;
  state.pendingImages += files.length;
  updateDraft();
  for (const file of files) {
    try {
      if (!['image/jpeg','image/png','image/webp'].includes(file.type)) throw new Error('Choose a JPEG, PNG, or WebP image for this preview.');
      if (file.size > 8 * 1024 * 1024) throw new Error('Choose an image smaller than 8 MB.');
      const bitmap = await createImageBitmap(file);
      if (bitmap.width * bitmap.height > 24000000 || bitmap.width > 8000 || bitmap.height > 8000) { bitmap.close(); throw new Error('Choose an image under 24 megapixels and 8,000 pixels per side.'); }
      const ratio = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(bitmap.width * ratio);
      canvas.height = Math.round(bitmap.height * ratio);
      canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      bitmap.close();
      // Re-encode demo attachments rather than retaining original image metadata.
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
      if (!blob) throw new Error('That image could not be prepared. Try another.');
      if (draftVersion === state.draftVersion) state.images.push({url:URL.createObjectURL(blob)});
    } catch (error) {
      if (draftVersion === state.draftVersion) formError(error.message || 'That image could not be opened.');
    } finally {
      state.pendingImages -= 1;
      renderImages();
    }
  }
}

function clearDraft(revokeImages = true) {
  state.draftVersion += 1;
  if (revokeImages) state.images.forEach(image => URL.revokeObjectURL(image.url));
  state.images = [];
  $('#post-text').value = '';
  $('#form-error').hidden = true;
  renderImages();
}

function setScreen(name, focus = false) {
  $$('.mobile-screen-tabs button').forEach(button => button.setAttribute('aria-pressed', button.dataset.screen === name));
  $$('.screen-study').forEach(screen => screen.classList.toggle('mobile-active', screen.id === `${name}-study`));
  if (focus) {
    const target = $(`#${name}-phone`);
    target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block:'nearest'});
    target.classList.remove('flash');
    requestAnimationFrame(() => target.classList.add('flash'));
    if (name === 'composer') $('#post-text').focus({preventScroll:true});
  }
}

function publish() {
  if (state.pendingImages) return;
  const text = $('#post-text').value.trim();
  if (!text && !state.images.length) return;
  if (Array.from(text).length > 2000) { formError('Keep your post to 2,000 characters.'); return; }
  if (state.identity === 'anonymous' && state.mode === 'custom') {
    const name = $('#custom-alias').value.trim();
    const normalized = name.normalize('NFKC').toLowerCase();
    if (name.length < 2 || name.length > 24) { formError('Choose a thread alias between 2 and 24 characters.'); return; }
    if (!/^[\p{L}\p{N} _.-]+$/u.test(name)) { formError('Use letters, numbers, spaces, dots, underscores, or hyphens.'); return; }
    if (/(^|[\s_.-])(admin|administrator|moderator|mod|support|system|official|veil)([\s_.-]|$)/u.test(normalized)) { formError('That name is reserved. Choose another thread alias.'); return; }
  }
  const anonymous = state.identity === 'anonymous';
  const expiry = $('#expiry').value;
  const post = {
    id:`demo-${Date.now()}-${state.posts.length}`, name:anonymous && state.mode === 'sigil' ? '' : currentAlias(), anonymous,
    presentation:anonymous ? state.mode : 'profile',
    sigil:currentSigil(), followed:!anonymous, mine:true, text, topic:$('#composer-topic').value,
    images:state.images.map(image => image.url), sensitive:state.sensitive,
    time:'Just now', likes:0, replies:0, expiry:expiry === 'Never' ? undefined : `${{'24 hours':'24h','7 days':'7d','30 days':'30d'}[expiry]} left`
  };
  state.posts.unshift(post);
  if (state.muted.has(post.topic)) state.muted.delete(post.topic);
  state.feed = 'discover'; state.topic = 'All';
  closeSheet(); renderFeed();
  $('#feed').scrollTop = 0;
  clearDraft(false);
  // Rotate the presentation for the next draft so consecutive threads differ.
  state.aliasIndex += 1;
  $('#custom-alias').value = '';
  renderIdentity();
  setScreen('discover', true);
  notify('Posted to the local preview. Nothing was sent to a server.');
}

$$('[data-feed]').forEach(button => button.addEventListener('click', () => { state.feed = button.dataset.feed; renderFeed(); $('#feed').scrollTop = 0; }));
$('.feed-tabs').addEventListener('keydown', event => {
  if (!['ArrowLeft','ArrowRight','Home','End'].includes(event.key)) return;
  event.preventDefault();
  state.feed = event.key === 'Home' ? 'discover' : event.key === 'End' ? 'following' : state.feed === 'discover' ? 'following' : 'discover';
  renderFeed(); $(`#tab-${state.feed}`).focus();
});
$$('.topic-list [data-topic]').forEach(button => button.addEventListener('click', () => setTopic(button.dataset.topic)));
$('#feed').addEventListener('click', handlePostAction);
$('#sheet-content').addEventListener('click', handlePostAction);
$('#close-sheet').addEventListener('click', closeSheet);
$('#sheet-backdrop').addEventListener('click', closeSheet);
document.addEventListener('keydown', event => {
  if ($('#detail-sheet').hidden) return;
  if (event.key === 'Escape') { event.preventDefault(); closeSheet(); }
  if (event.key === 'Tab') {
    const focusable = $$('button,input,select,textarea,a[href]', $('#detail-sheet')).filter(el => !el.disabled && !el.hidden && el.getClientRects().length);
    const first = focusable[0], last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
});
$('#nav-discover').addEventListener('click', () => { closeSheet(); state.feed = 'discover'; setTopic('All'); });
$('#nav-search').addEventListener('click', showSearch);
$('#nav-activity').addEventListener('click', showActivity);
$('#nav-inbox').addEventListener('click', () => presentSheet('Inbox', `<div class="sheet-empty">${icon('chat')}<h3>The start of something.</h3><p>Your conversations and message requests<br>will appear here.</p></div><p class="sheet-copy">Anonymous requests are filtered by default. You choose who gets a reply.</p>`));
$('#open-compose').addEventListener('click', () => setScreen('composer', true));
$('#feed-settings').addEventListener('click', () => {
  presentSheet('Make it your space.', `<p class="sheet-copy">Muted topics are filtered before posts appear.</p><p class="sheet-copy">${state.muted.size ? `Muted: ${escapeHTML([...state.muted].join(', '))}` : 'You haven’t muted any topics.'}</p><button class="sheet-button" id="reset-feed">Reset hidden posts and muted topics${icon('refresh')}</button>`);
  $('#reset-feed').addEventListener('click', () => { state.hidden.clear(); state.muted.clear(); closeSheet(); renderFeed(); notify('Your feed preferences have been reset.'); });
});
$$('[data-identity]').forEach(button => button.addEventListener('click', () => { state.identity = button.dataset.identity; renderIdentity(); }));
$$('[data-mode]').forEach(button => button.addEventListener('click', () => { state.mode = button.dataset.mode; renderIdentity(); if (state.mode === 'custom') $('#custom-alias').focus(); }));
$('#custom-alias').addEventListener('input', () => { $('#posting-as').innerHTML = `Posting as <strong>${escapeHTML(currentAlias())}</strong>`; $('#form-error').hidden = true; });
$('#regenerate-alias').addEventListener('click', () => { state.aliasIndex += 1; renderIdentity(); });
$('#post-text').addEventListener('input', updateDraft);
$('#sensitive-toggle').addEventListener('click', () => { state.sensitive = !state.sensitive; $('#sensitive-toggle').setAttribute('aria-checked', state.sensitive); });
$('#clear-draft').addEventListener('click', () => { clearDraft(); $('#post-text').focus(); });
$('#publish').addEventListener('click', publish);
$('#image-input').addEventListener('change', event => { const files = [...event.target.files]; event.target.value = ''; attachImages(files); });
$('.attachment-button').addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); $('#image-input').click(); } });
$('#image-previews').addEventListener('click', event => {
  const button = event.target.closest('[data-remove-image]');
  if (!button) return;
  const [removed] = state.images.splice(Number(button.dataset.removeImage), 1);
  if (removed) URL.revokeObjectURL(removed.url);
  renderImages();
});
$$('.accent-controls [data-accent]').forEach(button => button.addEventListener('click', () => {
  document.documentElement.dataset.accent = button.dataset.accent;
  $$('.accent-controls button').forEach(item => item.setAttribute('aria-pressed', item === button));
  $('#palette-name').textContent = button.dataset.accent.toUpperCase();
}));
$('#theme-toggle').addEventListener('click', () => {
  const dark = document.documentElement.dataset.theme === 'dark';
  document.documentElement.dataset.theme = dark ? 'light' : 'dark';
  $('#theme-toggle').innerHTML = `${icon(dark ? 'moon' : 'sun')}<span>${dark ? 'Dark' : 'Light'}</span>`;
  $('#theme-toggle').setAttribute('aria-label', `Switch to ${dark ? 'dark' : 'light'} appearance`);
});
$$('[data-screen]').forEach(button => button.addEventListener('click', () => setScreen(button.dataset.screen)));

setScreen('discover');
renderFeed();
renderIdentity();
updateDraft();
