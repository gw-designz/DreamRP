import { useSelector } from 'react-redux';
import './AppScreen.css';
import { getApp } from '../../app/registry';
import { selectExternalApp } from '../../store/slices/appsSlice';
import ExternalApp from '../../app/external/ExternalApp';
import { useT } from '../../i18n/useT';
import { usesIosApps } from '../../duo/skin';

export default function AppScreen({ appId }) {
    const t = useT();
    const external = useSelector(selectExternalApp(appId));
    const ios = useSelector((s) => usesIosApps(s.phone.ui.homeStyle));
    if (external) return <ExternalApp app={external} />;

    const app = getApp(appId);
    if (!app) return null;

    if (app.component) {
        const AppComponent = (ios && app.ios) || app.component;
        return <AppComponent />;
    }

    return (
        <div className="appscreen">
            <div className="appscreen__placeholder">
                <span className="appscreen__icon">
                    <img src={app.icon} alt="" />
                </span>
                <div className="appscreen__name">{app.name}</div>
                <div className="appscreen__soon">{t('common.comingSoonShort')}</div>
                <div className="appscreen__hint">{t('common.goHomeHint')}</div>
            </div>
        </div>
    );
}