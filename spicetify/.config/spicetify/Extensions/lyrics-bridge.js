(async function LyricsBridge() {
    while (!Spicetify?.Player?.addEventListener || !Spicetify?.Platform?.Session) {
        await new Promise(r => setTimeout(r, 300));
    }

    // Aspetta che il player abbia una traccia caricata
    while (!Spicetify.Player.data?.item?.uri) {
        await new Promise(r => setTimeout(r, 300));
    }

    const SPICY_URL = "https://api.spicylyrics.org/query";
    const SPICY_VERSION = "5.19.12";
    const SERVER_URL = "http://127.0.0.1:9876";

    let currentRequestId = 0;
    let serverToken = null;

    async function getServerToken() {
        if (serverToken) return serverToken;
        try {
            const resp = await new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                xhr.open("GET", `${SERVER_URL}/token`);
                xhr.onload = () => resolve(xhr.responseText);
                xhr.onerror = reject;
                xhr.send();
            });
            serverToken = resp;
            return serverToken;
        } catch (e) {
            return null;
        }
    }

    async function getToken() {
        try {
            const r = await Spicetify.CosmosAsync.get("sp://oauth/v2/token");
            //console.log("[LyricsBridge] token via CosmosAsync ok, prefix:", r.accessToken?.slice(0,20));
            return r.accessToken;
        } catch (e) {
            //console.warn("[LyricsBridge] CosmosAsync token failed, fallback:", e.message);
            return Spicetify.Platform.Session.accessToken;
        }
    }

    async function fetchAndWrite() {
        const requestId = ++currentRequestId;

        // Aspetta che il player sia attivo (token fresco garantito)
        if (!Spicetify.Player.isPlaying) {
            await new Promise(resolve => {
                const check = () => {
                    if (requestId !== currentRequestId) { resolve(); return; }
                    if (Spicetify.Player.isPlaying) { resolve(); return; }
                    setTimeout(check, 100);
                };
                setTimeout(check, 100);
            });
        }
        if (requestId !== currentRequestId) return;

        const uri = Spicetify.Player.data?.item?.uri;
        if (!uri) return;

        const trackId = uri.split(":")[2];
        const token = await getToken();
        if (requestId !== currentRequestId) return;

        try {
            // Tentativo 1: SpicyLyrics (word sync)
            let spicy = null;
            try {
                const spicyRaw = await new Promise((resolve) => {
                    const xhr = new XMLHttpRequest();
                    xhr.open("POST", SPICY_URL);
                    xhr.setRequestHeader("Content-Type", "application/json");
                    xhr.setRequestHeader("SpicyLyrics-Version", SPICY_VERSION);
                    xhr.setRequestHeader("SpicyLyrics-WebAuth", `Bearer ${token}`);
                    xhr.onload = () => {
                        if (requestId !== currentRequestId) { resolve(null); return; }
                        try { resolve(JSON.parse(xhr.responseText)); } catch(e) { resolve(null); }
                    };
                    xhr.onerror = () => resolve(null);
                    xhr.send(JSON.stringify({
                        queries: [{ operation: "lyrics", operationId: "0",
                            variables: { id: trackId, auth: "SpicyLyrics-WebAuth" } }],
                            client: { version: SPICY_VERSION }
                    }));                    
                });
                if (requestId !== currentRequestId) return;
                spicy = spicyRaw?.queries?.[0]?.result?.data ?? null;
                if (requestId !== currentRequestId) return;
                //console.log("[LyricsBridge]", trackId, "type:", spicy?.Type, "hasContent:", !!spicy?.Content?.length);
                //console.log("[LyricsBridge] raw response:", JSON.stringify(spicyRaw)?.slice(0, 300));

                // Retry se non-Syllable o se token completamente degradato
                const isCompleteFail = !spicy || (spicy.Type !== "Line" && !spicy.Content?.length);
                if (spicy?.Type !== "Syllable") {
                    // Attesa piu' lunga in caso di degrado completo (token scaduto dopo pausa lunga)
                    const retryDelay = isCompleteFail ? 3000 : 800;
                    await new Promise(r => setTimeout(r, retryDelay));
                    if (requestId !== currentRequestId) return;
                    try {
                        const token2 = await getToken();
                        if (requestId !== currentRequestId) return;
                        const spicy2Raw = await new Promise((resolve) => {
                            const xhr2 = new XMLHttpRequest();
                            xhr2.open("POST", SPICY_URL);
                            xhr2.setRequestHeader("Content-Type", "application/json");
                            xhr2.setRequestHeader("SpicyLyrics-Version", SPICY_VERSION);
                            xhr2.setRequestHeader("SpicyLyrics-WebAuth", `Bearer ${token2}`);
                            xhr2.onload = () => {
                                if (requestId !== currentRequestId) { resolve(null); return; }
                                try { resolve(JSON.parse(xhr2.responseText)); } catch(e) { resolve(null); }
                            };
                            xhr2.onerror = () => resolve(null);
                            xhr2.send(JSON.stringify({
                                queries: [{ operation: "lyrics", operationId: "0",
                                    variables: { id: trackId, auth: "SpicyLyrics-WebAuth" } }],
                                client: { version: SPICY_VERSION }
                            }));
                        });
                        if (requestId !== currentRequestId) return;
                        const spicy2 = spicy2Raw?.queries?.[0]?.result?.data ?? null;
                        //console.log("[LyricsBridge] retry", trackId, "type:", spicy2?.Type, "hasContent:", !!spicy2?.Content?.length);
                        if (spicy2?.Type === "Syllable") {
                            spicy = spicy2;
                            //console.log("[LyricsBridge] retry Syllable ok for", trackId);
                        } else if (isCompleteFail && spicy2?.Content?.length) {
                            // Degrado parziale recuperato (Line): meglio di niente
                            spicy = spicy2;
                        }
                    } catch (retryErr) {
                        // retry fallito, si procede con il valore originale
                    }
                }
            } catch (spicyErr) {
                if (requestId !== currentRequestId) return;
                //console.warn("[LyricsBridge] SpicyLyrics failed, falling back:", spicyErr.message);
            }

            if (requestId !== currentRequestId) return;

            let lyrics = null;
            let lyricsSource = "spicy";

            if (spicy && spicy.Type === "Syllable") {
                lyrics = spicy;
            } else {
                // Fallback: API Spotify nativa (LINE_SYNCED)
                const sd = await new Promise((resolve, reject) => {
                    const xhr = new XMLHttpRequest();
                    xhr.open("GET", `https://spclient.wg.spotify.com/color/lyrics/v2/track/${trackId}?format=json&vocalRemoval=false`);
                    xhr.setRequestHeader("Authorization", `Bearer ${token}`);
                    xhr.setRequestHeader("App-Platform", "WebPlayer");
                    xhr.onload = () => { 
                        if (requestId !== currentRequestId) { resolve(null); return; }
                        try { resolve(JSON.parse(xhr.responseText)) } catch(e) { resolve(null) } };
                    xhr.onerror = () => resolve(null);
                    xhr.send();
                });
                if (sd?.lyrics && sd.lyrics.syncType !== "UNSYNCED") {
                    lyrics = sd.lyrics;
                    lyricsSource = "spotify";
                } else if (spicy?.Type === "Line" && spicy.Content?.length) {
                    // Spotify native non disponibile, usa spicy Line come fallback
                    lyrics = spicy;
                }
            }

            if (requestId !== currentRequestId) return;
            
            if (!lyrics) return;

            // Controlla se la traccia e' nei preferiti
            const isLiked = Spicetify.Player.getHeart();
            if (requestId !== currentRequestId) return;

            // Scrivi al server locale con retry + auth token
            for (let attempt = 0; attempt < 3; attempt++) {
                try {
                    const srvToken = await getServerToken();
                    await new Promise((resolve, reject) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open("POST", `${SERVER_URL}/lyrics`);
                        xhr.setRequestHeader("Content-Type", "application/json");
                        if (srvToken) xhr.setRequestHeader("Authorization", `Bearer ${srvToken}`);
                        xhr.onload = () => {
                            if (xhr.status === 403) { serverToken = null; reject(new Error("token expired")); }
                            else resolve();
                        };
                        xhr.onerror = reject;
                        xhr.send(JSON.stringify({ trackId, lyrics, lyricsSource, isLiked }));
                    });
                    break;
                } catch (postErr) {
                    serverToken = null;  // forza refresh token al prossimo tentativo
                    if (attempt < 2) await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
                    else console.warn("[LyricsBridge] POST fallito dopo 3 tentativi");
                }
            }
            //console.log("[LyricsBridge] scritto:", trackId, lyricsSource, spicy?.Type ?? lyrics.syncType);
        } catch (e) {
            const msg = e instanceof ProgressEvent ? `XHR errror (type=${e.type}, server down?)` : e.message ?? e;
            console.error("[LyricsBridge]", msg);
        }
    }

    Spicetify.Player.addEventListener("songchange", fetchAndWrite);
    fetchAndWrite();

    // Like/Unlike via polling
    async function checkLiked(trackId) {
        try {
            const heart = Spicetify.Player.getHeart();
            //console.log("[LyricsBridge] checkLiked (getHeart):", heart);
            return heart;
        } catch (e) {
            console.warn("[LyricsBridge] checkLiked:", e);
            return false;
        }
    }

    async function toggleLike(trackId) {
        try {
            const wasBefore = Spicetify.Player.getHeart();
            await Spicetify.Player.toggleHeart();
            // Aspetta che lo stato si aggiorni
            await new Promise(r => setTimeout(r, 500));
            const isNow = Spicetify.Player.getHeart();
            //console.log("[LyricsBridge] toggleLike:", wasBefore, "->", isNow);
            return isNow;
        } catch (e) {
            console.warn("[LyricsBridge] toggleLike error:", e);
            return false;
        }
    }

    // Polling: controllo se quickshell ha inviato un comando like
    setInterval(async () => {
        try {
            const srvToken = await getServerToken();
            if (!srvToken) return;
            const resp = await new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                xhr.open("GET", `${SERVER_URL}/pending`);
                xhr.setRequestHeader("Authorization", `Bearer ${srvToken}`)
                xhr.onload = ()  => resolve(xhr.responseText);
                xhr.onerror = () => resolve("{}");
                xhr.send();
            });
            const cmd = JSON.parse(resp);
            //console.log("[LyricsBridge] pending cmd:", JSON.stringify(cmd));
            if (cmd.action === "toggleLike" && cmd.trackId) {
                const newState = await toggleLike(cmd.trackId);
                // Notifica quickshell dello stato aggiornato
                const srvToken2 = await getServerToken();
                const xhr2 = new XMLHttpRequest();
                xhr2.open("POST", `${SERVER_URL}/lyrics`);
                xhr2.setRequestHeader("Content-Type", "application/json");
                if (srvToken2) xhr2.setRequestHeader("Authorization", `Bearer ${srvToken2}`);
                xhr2.send(JSON.stringify({
                    trackId: cmd.trackId,
                    likeState: newState
                }));
                //console.log("[LyricsBridge] sent likeState:", newState, "for:", cmd.trackId);
            }
        } catch (e) { }
    }, 1000);       // ogni secondo
})();