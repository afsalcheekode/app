const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, doc, setDoc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkTeacherPhotos() {
    console.log('Fetching all teacher_photos...');
    const snapshot = await getDocs(collection(db, 'teacher_photos'));
    snapshot.forEach(doc => {
        console.log(`Photo Doc ID: ${doc.id}`);
    });
}

checkTeacherPhotos().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
