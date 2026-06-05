const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, doc, setDoc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function transferPhotos() {
    console.log('Fetching all users...');
    const usersSnapshot = await getDocs(collection(db, 'users'));
    const allUsers = [];
    usersSnapshot.forEach(doc => {
        allUsers.push({ id: doc.id, ...doc.data() });
    });

    console.log(`Found ${allUsers.length} total users.`);

    // Build a map of old users (or any user) by name, prioritizing those with a photo
    const nameToPhotoMap = {};
    allUsers.forEach(u => {
        if (u.role === 'student' && u.name) {
            const photo = u.photoUrl || u.photoURL || u.image || u.imageUrl || u.profileUrl;
            if (photo) {
                nameToPhotoMap[u.name.trim()] = photo;
            }
        }
    });

    console.log(`Found ${Object.keys(nameToPhotoMap).length} unique student names with photos.`);
    console.log(nameToPhotoMap);

    // Now update central_store and the newly created users
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);
    const data = centralStoreSnap.data();

    const students = data.allStudents || [];
    let updatedCount = 0;

    for (let i = 0; i < students.length; i++) {
        if (students[i].schoolName === 'كلية حياة الإسلام') {
            const photo = nameToPhotoMap[students[i].name.trim()];
            if (photo) {
                // Update in central_store array
                students[i].photoUrl = photo;
                
                // Update in the specific user doc
                if (students[i].uid) {
                    await setDoc(doc(db, 'users', students[i].uid), { photoUrl: photo }, { merge: true });
                }
                updatedCount++;
            }
        }
    }

    if (updatedCount > 0) {
        data.allStudents = students;
        await setDoc(centralStoreRef, data, { merge: true });
        console.log(`Successfully restored photos for ${updatedCount} students.`);
    } else {
        console.log(`No photos were restored. Maybe none matched or none existed.`);
    }
}

transferPhotos().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
