const fs = require('fs');

const credentials = JSON.parse(fs.readFileSync('pattern_credentials.json', 'utf8'));

const photoDocs = [
"abidjhz02", "abisinanjnr02", "adnanjnr02", "ahs", "ahs04", "ahsanhs01", "althafhz04", "ameenhz03", "ameenjnr02", "asifhz04", "aslambs02", "aslamjnr02", "faezhz03", "farhanhz01", "farhanjnr02", "farooqhs01", "ha1993", "hafishs02", "hashirhz01", "hishamhz01", "hsh", "hsh04", "irfanbs02", "irfanhz04", "ishamhz04", "izhaqhz04", "juniadhs02", "mabidhz02", "mah", "mah04", "mansoorbs01", "mithlajhz03", "muadbs01", "muktharjnr02", "mun", "mun04", "musthafabs02", "musthfajnr01", "nafilhz02", "najadjnr02", "ramadanhz03", "razakhs01", "rizwanhz03", "sabithjnr02", "safwanhz03", "sajidhs01", "sajidjnr01", "salimhs01", "salmanhs01", "sayyidbs01", "sayyidhs01", "shahidjnr01", "shahidsjnr01", "shammashz04", "sinanhz01", "ssahadjnr01", "swabirhz03", "swalihhz03", "thameemjnr01", "yahyahs02", "yaseenhz03", "yaseennhz03", "yaseerhs01", "zayanhz02"
];

function simplify(str) {
    return str.toLowerCase().replace(/[^a-z0-9]/g, '');
}

const mapping = {};

for (const photoId of photoDocs) {
    let bestMatch = null;
    let maxScore = 0;
    
    for (const student of credentials) {
        const parts = student.name.toLowerCase().split(' ');
        const cls = student.class.toLowerCase();
        
        // Ex: "aslamjnr02" -> name "MUHAMMED ASLAM", class "JNR02"
        let score = 0;
        for (const p of parts) {
            if (p.length > 2 && photoId.includes(p)) score += 10;
        }
        if (photoId.includes(cls)) score += 5;
        
        // Exact last name + class match is a very strong signal
        const lastName = parts[parts.length - 1];
        if (photoId === (lastName + cls)) {
            score += 50;
        }
        
        // Or exact first name + class
        const firstName = parts[0];
        if (photoId === (firstName + cls)) {
            score += 50;
        }

        if (score > maxScore) {
            maxScore = score;
            bestMatch = student;
        }
    }
    
    if (maxScore > 0) {
        mapping[photoId] = bestMatch.newUsername;
        console.log(`${photoId.padEnd(20)} -> ${bestMatch.newUsername.padEnd(10)} (${bestMatch.name} - ${bestMatch.class}) Score: ${maxScore}`);
    } else {
        console.log(`${photoId.padEnd(20)} -> NO MATCH`);
    }
}
