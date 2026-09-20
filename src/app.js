let teams = [];

function initLeague() {
    const name = document.getElementById('league-name').value.trim();
    const inputTeams = document.getElementById('league-teams').value.trim();

    if (!name || !inputTeams) {
        alert("Tafadhali jaza jina la ligi na timu zote!");
        return;
    }

    const teamList = inputTeams.split(',').map(t => t.trim()).filter(t => t !== "");

    if (teamList.length < 2) {
        alert("Tafadhali weka angalau timu 2 au zaidi!");
        return;
    }

    teams = teamList.map((tName, i) => ({
        id: i + 1,
        name: tName,
        p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0, gd: 0, pts: 0
    }));

    document.getElementById('tourney-title').innerText = name + " - League Standings";
    document.getElementById('scan-section').style.display = 'block';
    document.getElementById('table-section').style.display = 'block';

    renderTable();
}

function renderTable() {
    teams.sort((a, b) => b.pts - a.pts || b.gd - a.gd);
    const tbody = document.getElementById('league-tbody');

    tbody.innerHTML = teams.map((t, idx) => `
        <tr>
            <td><strong>${idx + 1}</strong></td>
            <td><strong>${t.name}</strong></td>
            <td>${t.p}</td>
            <td>${t.w}</td>
            <td>${t.d}</td>
            <td>${t.l}</td>
            <td>${t.gd > 0 ? '+' : ''}${t.gd}</td>
            <td><strong style="color:var(--gold-primary);">${t.pts}</strong></td>
        </tr>
    `).join('');
}

async function processScreenshot(event) {
    const file = event.target.files[0];
    if (!file) return;

    const statusDiv = document.getElementById('scan-status');
    statusDiv.innerHTML = "<i class='fa-solid fa-spinner fa-spin'></i> Inasoma Screenshot... Tafadhali subiri kidogo.";

    try {
        const worker = await Tesseract.createWorker('eng');
        const ret = await worker.recognize(file);
        await worker.terminate();

        const extractedText = ret.data.text;
        statusDiv.innerHTML = "<span style='color:#10b981;'><i class='fa-solid fa-circle-check'></i> Screenshot Imesomwa Kufanikiwa!</span>";

        parseAndApplyResults(extractedText);
    } catch (err) {
        console.error(err);
        statusDiv.innerHTML = "<span style='color:#ef4444;'>Imefeli kusoma screenshot. Jaribu picha iliyo wazi zaidi.</span>";
    }
}

function parseAndApplyResults(text) {
    const numbers = text.match(/\b\d+\b/g);

    if (numbers && numbers.length >= 2) {
        const homeScore = parseInt(numbers[0]);
        const awayScore = parseInt(numbers[1]);

        if (teams.length >= 2) {
            const homeTeam = teams[0];
            const awayTeam = teams[1];

            updateTeamStats(homeTeam, awayTeam, homeScore, awayScore);
            renderTable();

            alert(`Matokeo Yaliyosomwa kutoka Screenshot:\n${homeTeam.name} ${homeScore} - ${awayScore} ${awayTeam.name}\n\nMsimamo wa Ligi umebadilishwa!`);
        }
    } else {
        alert("Hatukuweza kupata matokeo wazi kwenye picha. Hakikisha umei-crop sehemu ya Scoreboard vizuri.");
    }
}

function updateTeamStats(home, away, hScore, aScore) {
    home.p += 1;
    away.p += 1;

    home.gf += hScore; home.ga += aScore; home.gd = home.gf - home.ga;
    away.gf += aScore; away.ga += hScore; away.gd = away.gf - away.ga;

    if (hScore > aScore) {
        home.w += 1; home.pts += 3;
        away.l += 1;
    } else if (hScore < aScore) {
        away.w += 1; away.pts += 3;
        home.l += 1;
    } else {
        home.d += 1; home.pts += 1;
        away.d += 1; away.pts += 1;
    }
}
