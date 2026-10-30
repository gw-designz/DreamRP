import{d as e,r as t,j as a,a2 as r,u as n,bW as s,fR as i}from"./vendor-8f9a1d00.js";import{u as o,a as c,f as l,M as g,e as f,C as d,E as m,d as u}from"./index-e43e59d9.js";const h=e.div.attrs({className:"tgg-banking-transfer-tab"})`
	display: flex;
	flex-direction: column;
	height: 100%;
	overflow: hidden;
	padding: 0 1.5rem;
	font-family: Manrope, sans-serif;
	background-color: ${e=>e.$isDark?"#101922":"#f8fafc"};
	color: ${e=>e.$isDark?"#fff":"#1e293b"};

	.tgg-transfer-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.25rem 0 0.5rem 0;
		flex-shrink: 0;
	}

	.tgg-transfer-back-btn {
		padding: 0.5rem;
		margin-left: -0.5rem;
		border-radius: 50%;
		background: none;
		border: none;
		cursor: pointer;
		color: ${e=>e.$isDark?"#fff":"#1e293b"};
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;

		&:hover {
			background: ${e=>e.$isDark?"rgba(255,255,255,0.1)":"rgba(0,0,0,0.05)"};
		}
	}

	.tgg-transfer-title {
		font-size: calc(1rem * ${e=>e.$resizeBy});
		font-weight: 700;
		margin: 0;
	}

	.tgg-transfer-spacer {
		width: 2.5rem;
	}

	.tgg-transfer-search-wrapper {
		position: relative;
		margin: 0.25rem 0 1rem 0;
		flex-shrink: 0;
	}

	.tgg-transfer-search-icon {
		position: absolute;
		left: 0.625rem;
		top: 50%;
		transform: translateY(-50%);
		color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		pointer-events: none;
		font-size: 1.25rem;
	}

	.tgg-transfer-search-input {
		width: 100%;
		padding: 0.5rem 0.75rem 0.5rem 2.25rem;
		border: none;
		border-radius: 0.625rem;
		font-size: 0.8125rem;
		background: ${e=>e.$isDark?"rgba(255, 255, 255, 0.05)":"#fff"};
		color: ${e=>e.$isDark?"#fff":"#1e293b"};
		border: 1px solid
			${e=>e.$isDark?"rgba(255, 255, 255, 0.1)":"rgba(0, 0, 0, 0.08)"};
		backdrop-filter: blur(10px);
		-webkit-backdrop-filter: blur(10px);

		&::placeholder {
			color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		}

		&:focus {
			outline: none;
			box-shadow: 0 0 0 2px rgba(19, 127, 236, 0.5);
		}
	}

	.tgg-transfer-inline-input {
		width: 100%;
		padding: 0;
		margin-top: -0.125rem;
		border: none;
		background: transparent;
		font-size: calc(0.875rem * ${e=>e.$resizeBy});
		font-weight: 700;
		color: inherit;
		font-family: inherit;

		&::placeholder {
			color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		}

		&:focus {
			outline: none;
		}
	}

	.tgg-transfer-section-title {
		font-size: 9px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		margin: 0 0 0.5rem 0;
	}

	.tgg-transfer-contacts-scroll {
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}

	.tgg-transfer-contact-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		padding: 0.5rem 0.75rem;
		margin-bottom: 0.25rem;
		border-radius: 0.625rem;
		background: none;
		border: none;
		cursor: pointer;
		text-align: left;
		transition: background 0.2s;

		&:hover {
			background: ${e=>e.$isDark?"rgba(255, 255, 255, 0.08)":"rgba(0, 0, 0, 0.06)"};
		}
	}

	.tgg-transfer-contact-left {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		min-width: 0;
		flex: 1;
	}

	.tgg-transfer-avatar {
		width: calc(2rem * ${e=>e.$resizeBy});
		height: calc(2rem * ${e=>e.$resizeBy});
		min-width: 32px;
		min-height: 32px;
		border-radius: 50%;
		overflow: hidden;
		background: ${e=>e.$isDark?"#374151":"#e2e8f0"};
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;

		img {
			width: 100%;
			height: 100%;
			object-fit: cover;
		}

		.tgg-transfer-avatar-initials {
			font-size: calc(0.75rem * ${e=>e.$resizeBy});
			font-weight: 600;
			color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		}
	}

	.tgg-transfer-contact-details {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		min-width: 0;
		flex: 1;
	}

	.tgg-transfer-contact-name {
		font-size: calc(0.8125rem * ${e=>e.$resizeBy});
		font-weight: 700;
		color: ${e=>e.$isDark?"#fff":"#1e293b"};
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		width: 100%;
	}

	.tgg-transfer-contact-number {
		font-size: 9px;
		color: ${e=>e.$isDark?"#9ca3af":"#64748b"};
		margin-top: 0.0625rem;
	}

	.tgg-transfer-chevron {
		color: ${e=>e.$isDark?"#9ca3af":"#94a3b8"};
		flex-shrink: 0;
		font-size: 1.125rem;
		transition: color 0.2s;

		.tgg-transfer-contact-row:hover & {
			color: #137fec;
		}
	}

	.tgg-transfer-direct-number {
		.tgg-transfer-avatar {
			border: 2px dashed rgba(19, 127, 236, 0.5);
			background: rgba(19, 127, 236, 0.1);
			color: #137fec;
		}

		.tgg-transfer-avatar-initials {
			color: #137fec;
		}

		.tgg-transfer-contact-name {
			color: #137fec;
		}

		.tgg-transfer-chevron {
			color: #137fec;
		}
	}
`,p=e=>{var t;const a=e.split(" ").filter(Boolean);return a.length>=2?a[0].charAt(0).toUpperCase()+a.at(-1).charAt(0).toUpperCase():(null==(t=a[0])?void 0:t.charAt(0).toUpperCase())||"#"},b=(e,t)=>{const a=(e.name??"").toLowerCase().includes(t),r=t.replaceAll(/\D/g,"");if(0===r.length)return a;const n=(e.number??"").replaceAll(/\D/g,"");return a||n.includes(r)},x=t.memo(({contact:e,onClick:t})=>a.jsxs("button",{type:"button",className:"tgg-transfer-contact-row",onClick:()=>t(e),children:[a.jsxs("div",{className:"tgg-transfer-contact-left",children:[a.jsx("div",{className:"tgg-transfer-avatar",children:a.jsx("span",{className:"tgg-transfer-avatar-initials",children:p(e.name)})}),a.jsxs("div",{className:"tgg-transfer-contact-details",children:[a.jsx("div",{className:"tgg-transfer-contact-name",children:e.name}),a.jsx("div",{className:"tgg-transfer-contact-number",children:e.number})]})]}),a.jsx(r,{className:"tgg-transfer-chevron"})]}));x.displayName="ContactItem";const k=t.memo(({accountBalance:e,action:k,onBack:v})=>{const{t:y}=n(),[$,j]=t.useState(""),[w,N]=t.useState(!1),[C,D]=t.useState(""),[z,B]=t.useState(""),T=o(e=>e.phoneData.contacts),L=o(e=>e.phoneIdentifiers.number),S=o(e=>e.settings),A=o(e=>e.resizeBy),M="dark"===(null==S?void 0:S.theme),I=c(e=>e.setSideModalOpen),[R,U]=t.useState([]);t.useEffect(()=>{L&&l("ypay:get-transactions",{phoneNumber:L,page:0},{transactions:u.transactions.slice(0,15),totalTransactions:u.totalTransactions}).then(e=>{var t;(null==(t=null==e?void 0:e.transactions)?void 0:t.length)&&U(e.transactions)})},[L]);const E=t.useMemo(()=>{if(!T)return[];if(!z.trim())return T;const e=z.toLowerCase().trim();return T.filter(t=>b(t,e))},[T,z]),F=t.useMemo(()=>{if(!R.length||!L)return[];const e=new Set,t=[],a=e=>(null==e?void 0:e.replaceAll(/\D/g,""))??"";for(const r of R){const n=r.senderNumber===L?r.recipientNumber:r.senderNumber;if(!n||n===L)continue;const s=a(n);if(e.has(s))continue;e.add(s);const i=null==T?void 0:T.find(e=>a(e.number)===s);if(t.push(i?{...i}:{id:0,name:y("ypay.unknownRecipient"),number:n}),t.length>=3)break}return t},[R,L,T,y]),P=t.useMemo(()=>{let e;if(""!==z.trim()||0===F.length)e=E;else{const t=new Set(F.filter(e=>e.id>0).map(e=>e.id));e=E.filter(e=>!t.has(e.id))}return t=e,[...t].sort((e,t)=>(e.name??"").localeCompare(t.name??"",void 0,{sensitivity:"base"}));var t},[E,F,z]),O=t.useCallback(e=>{B(e.target.value)},[]),W=t.useCallback(t=>{I({status:!0,modal:g.BankTransfer,side:"left",zIndex:100,data:{action:k,contact:t,accountBalance:e,initials:p(t.name)}})},[k,e,I]),Y=t.useCallback(async()=>{if(C.trim()&&C!==$){try{await l("phone:validate-sim-number",C,!0)&&C!==$?I({status:!0,modal:g.BankTransfer,side:"left",zIndex:100,data:{action:k,contact:{id:0,name:y("ypay.unknownRecipient"),number:C},accountBalance:e,initials:"#"}}):f({action:"ui:notify",internal:!0,data:"messages.invalidNumber"})}catch{f({action:"ui:notify",internal:!0,data:"messages.invalidNumber"})}j(C)}},[C,$,k,e,y,I]),q=t.useCallback(()=>{w&&C?Y():N(!0)},[w,C,Y]),G=t.useCallback(e=>{D(e.target.value)},[]),H=""===z.trim()&&F.length>0,J=t.useMemo(()=>{if(!z.trim())return F;const e=z.toLowerCase().trim();return F.filter(t=>b(t,e))},[F,z]);return a.jsxs(h,{$resizeBy:A,$isDark:M,children:[a.jsxs("header",{className:"tgg-transfer-header",children:[a.jsx("button",{type:"button",className:"tgg-transfer-back-btn",onClick:v,"aria-label":y("ypay.transferToLabel","Back"),children:a.jsx(s,{size:24})}),a.jsx("h1",{className:"tgg-transfer-title",children:y("ypay.transferToLabel","Transfer to")}),a.jsx("div",{className:"tgg-transfer-spacer"})]}),a.jsxs("div",{className:"tgg-transfer-search-wrapper",children:[a.jsx(i,{className:"tgg-transfer-search-icon"}),a.jsx("input",{className:"tgg-transfer-search-input",placeholder:y("ypay.searchLabel"),value:z,onChange:O,type:"text"})]}),a.jsx("div",{className:"tgg-transfer-contacts-scroll",children:a.jsx(d,{children:a.jsxs("div",{style:{paddingBottom:"0.75rem"},children:[a.jsxs("button",{type:"button",className:"tgg-transfer-contact-row tgg-transfer-direct-number",onClick:q,children:[a.jsxs("div",{className:"tgg-transfer-contact-left",children:[a.jsx("div",{className:"tgg-transfer-avatar",children:a.jsx("span",{className:"tgg-transfer-avatar-initials",children:"#"})}),a.jsx("div",{className:"tgg-transfer-contact-details",children:w?a.jsx("input",{className:"tgg-transfer-inline-input",placeholder:y("ypay.enterPhoneNumber"),value:C,onChange:G,onClick:e=>e.stopPropagation(),type:"tel"}):a.jsx("div",{className:"tgg-transfer-contact-name",children:y("ypay.directToNumber")})})]}),a.jsx(r,{className:"tgg-transfer-chevron"})]}),H&&a.jsxs(a.Fragment,{children:[a.jsx("h3",{className:"tgg-transfer-section-title",children:y("ypay.recentContactsLabel","Recent Contacts")}),J.map(e=>a.jsx(x,{contact:e,onClick:W},e.id>0?e.id:`unknown-${e.number}`))]}),a.jsx("h3",{className:"tgg-transfer-section-title",children:y("ypay.allContactsLabel","All Contacts")}),0!==P.length||H?P.map(e=>a.jsx(x,{contact:e,onClick:W},e.id)):a.jsx(m,{text:y("ypay.notFoundLabel")})]})})})]})});k.displayName="TransferTab";export{k as TransferTab};
