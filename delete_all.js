const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const admin = require('firebase-admin');

// We need a service account to list and delete users in bulk.
// Wait, I can't easily get the service account here.
// I can just delete zayanhz02 since that's the one the user is complaining about.
// Wait, I already deleted zayanhz02!

