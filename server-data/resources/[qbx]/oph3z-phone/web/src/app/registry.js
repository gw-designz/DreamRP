import callIcon from '../assets/icons/apps/call.png';
import messageIcon from '../assets/icons/apps/message.png';
import cameraIcon from '../assets/icons/apps/camera.png';
import photosIcon from '../assets/icons/apps/photos.png';
import mapsIcon from '../assets/icons/apps/maps.png';
import clockIcon from '../assets/icons/apps/clock.png';
import mailIcon from '../assets/icons/apps/mail.png';
import walletIcon from '../assets/icons/apps/wallet.png';
import settingsIcon from '../assets/icons/apps/settings.png';
import calculatorIcon from '../assets/icons/apps/calculator.png';
import appstoreIcon from '../assets/icons/apps/appstore.png';
import twexaIcon from '../assets/icons/apps/twexa.png';
import marketplaceIcon from '../assets/icons/apps/yellowpages.png';

import PhoneApp from './phone/PhoneApp';
import PhotosApp from './photos/PhotosApp';
import CameraApp from './camera/CameraApp';
import MapsApp from './maps/MapsApp';
import MessagesApp from './messages/MessagesApp';
import AppStoreApp from './appstore/AppStoreApp';
import SettingsApp from './settings/SettingsApp';
import ClockApp from './clock/ClockApp';
import CalculatorApp from './calculator/CalculatorApp';
import MailApp from './mail/MailApp';
import WalletApp from './wallet/WalletApp';
import SocialsApp from './socials/SocialsApp';
import { CallsApp, ChatsApp } from '../np/apps/phone/PhoneSuite';
import BankApp from '../np/apps/bank/BankApp';
import NpSettings from '../np/apps/settings/NpSettings';
import Gallery from '../np/apps/gallery/Gallery';
import LemonList from '../np/apps/lemon/LemonList';
import Garage from '../np/apps/garage/Garage';
import Licenses from '../np/apps/garage/Licenses';
import Business from '../np/apps/business/Business';
import Crypto from '../np/apps/crypto/Crypto';
import Calendar from '../np/apps/calendar/Calendar';
import Government from '../np/apps/government/Government';
import News from '../np/apps/news/News';
import Events from '../np/apps/events/Events';
import Property from '../np/apps/property/Property';
import RealEstate from '../np/apps/property/RealEstate';
import Guber from '../np/apps/guber/Guber';
import Roach from '../np/apps/misc/Roach';
import GreyBook from '../np/apps/misc/GreyBook';
import ScootE from '../np/apps/misc/ScootE';
import MarketApp from './marketplace/MarketApp';

export const APPS = {
    // NoPixel phone suite (Contacts · Chats · Calls · Keypad). The original iOS apps stay in
    // app/phone and app/messages and are used when Config.UI.HomeStyle = 'ios'.
    call: { id: 'call', name: 'Phone', icon: callIcon, component: CallsApp, ios: PhoneApp },
    message: { id: 'message', name: 'Messages', icon: messageIcon, component: ChatsApp, ios: MessagesApp },
    camera: { id: 'camera', name: 'Camera', icon: cameraIcon, component: CameraApp },
    photos: { id: 'photos', name: 'Gallery', icon: photosIcon, component: Gallery, ios: PhotosApp },
    maps: { id: 'maps', name: 'Maps', icon: mapsIcon, component: MapsApp },
    clock: { id: 'clock', name: 'Clock', icon: clockIcon, component: ClockApp },
    mail: { id: 'mail', name: 'Mail', icon: mailIcon, component: MailApp },
    wallet: { id: 'wallet', name: 'Bank', icon: walletIcon, component: BankApp, ios: WalletApp },
    settings: { id: 'settings', name: 'Settings', icon: settingsIcon, component: NpSettings, ios: SettingsApp },
    calculator: {
        id: 'calculator',
        name: 'Calculator',
        icon: calculatorIcon,
        component: CalculatorApp,
    },
    appstore: { id: 'appstore', name: 'App Store', icon: appstoreIcon, component: AppStoreApp },
    // Socials is the NoPixel front end for the Twexa backend; it keeps the 'twexa' id so
    // notifications, ShareDrop and camera hand-offs that target 'twexa' keep working.
    twexa: { id: 'twexa', name: 'Socials', icon: twexaIcon, component: SocialsApp },
    marketplace: { id: 'marketplace', name: 'Lemon List', icon: marketplaceIcon, component: LemonList, ios: MarketApp },

    // NoPixel home-grid apps
    business: { id: 'business', name: 'Business', component: Business },
    licenses: { id: 'licenses', name: 'Licenses', component: Licenses },
    garage: { id: 'garage', name: 'Garage', component: Garage },
    calendar: { id: 'calendar', name: 'Calendar', component: Calendar },
    crypto: { id: 'crypto', name: 'Crypto', component: Crypto },
    government: { id: 'government', name: 'Government', component: Government },
    guber: { id: 'guber', name: 'Guber', component: Guber },
    news: { id: 'news', name: 'Weazel', component: News },
    property: { id: 'property', name: 'Property', component: Property },
    realestate: { id: 'realestate', name: 'Real Estate', component: RealEstate },
    scoote: { id: 'scoote', name: 'Scoot-E', component: ScootE },
    events: { id: 'events', name: 'Events', component: Events },
    greybook: { id: 'greybook', name: 'Grey Book', component: GreyBook },
    roach: { id: 'roach', name: 'Roach', component: Roach },
};

export const getApp = (id) => APPS[id] || null;