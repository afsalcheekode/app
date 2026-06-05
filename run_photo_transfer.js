const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, doc, setDoc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const credentials = require('./pattern_credentials.json');

async function doTransfer() {
    console.log('Fetching all teacher_photos...');
    const snapshot = await getDocs(collection(db, 'teacher_photos'));
    
    let photoDocs = [];
    snapshot.forEach(doc => {
        photoDocs.push({ id: doc.id, photo: doc.data().photo });
    });
    
    let transfersCount = 0;
    
    // Also load central store to update photoUrl in user doc
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);
    const data = centralStoreSnap.data();
    const students = data.allStudents || [];

    for (const p of photoDocs) {
        const photoId = p.id;
        if (!p.photo) continue; // Skip if no photo content

        let bestMatch = null;
        let maxScore = 0;
        
        for (const student of credentials) {
            const normalizedName = student.name.toLowerCase().replace(/[^a-z0-9]/g, '');
            const cls = student.class.toLowerCase();
            
            let score = 0;
            
            const parts = student.name.toLowerCase().replace(/[^a-z0-9 ]/g, '').split(' ');
            const lastName = parts[parts.length - 1];
            const firstName = parts[0];
            
            if (photoId === (lastName + cls)) score += 50;
            if (photoId === (firstName + cls)) score += 50;
            if (photoId === (normalizedName + cls)) score += 60;
            
            if (photoId === 'muadbs01' && student.name === "MUHAMMED MU'AD" && cls === 'bs01') score += 100;
            if (photoId === 'salmanhs01' && student.name === "SALMANUL FARIS" && cls === 'hs01') score += 100;
            if (photoId === 'yaseennhz03' && student.name === "NOOR MUHAMMED YASEEN" && cls === 'hz03') score += 100;
            if (photoId === 'ssahadjnr01' && student.name === "SAHAD S" && cls === 'jnr01') score += 100;
            if (photoId === 'shahidsjnr01' && student.name === "SHAHID S" && cls === 'jnr01') score += 100;
            if (photoId === 'mabidhz02' && student.name === "ABID J" && cls === 'hz02') score += 100;
            if (photoId === 'abidjhz02' && student.name === "ABID J" && cls === 'hz02') score += 100; // duplicate photoId for same user?
            
            // Substring fallback if score still 0
            if (score === 0) {
               for (const part of parts) {
                  if (part.length > 2 && photoId.includes(part)) {
                     score += 10;
                  }
               }
               if (photoId.includes(cls)) score += 5;
            }

            if (score > maxScore) {
                maxScore = score;
                bestMatch = student;
            }
        }
        
        if (maxScore >= 15 && bestMatch) { // require a decent score to prevent wrong mappings
            const newUsername = bestMatch.newUsername;
            console.log(`Transferring ${photoId} -> ${newUsername} (${bestMatch.name})`);
            
            // Copy photo to new username in teacher_photos
            await setDoc(doc(db, 'teacher_photos', newUsername), {
                photo: p.photo,
                username: newUsername
            }, { merge: true });
            
            for (let i = 0; i < students.length; i++) {
                if (students[i].username === newUsername) {
                    if (students[i].uid) {
                        await setDoc(doc(db, 'users', students[i].uid), { photoUrl: p.photo }, { merge: true });
                    }
                    break;
                }
            }
            
            transfersCount++;
        } else {
             console.log(`Skipped ${photoId}: No confident match found.`);
        }
    }
    
    console.log(`Transferred ${transfersCount} photos.`);
}

doTransfer().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
