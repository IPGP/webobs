// -------------------------------------------------------------------
// markItUp!
// -------------------------------------------------------------------
// Copyright (C) 2008 Jay Salvat
// http://markitup.jaysalvat.com/
// -------------------------------------------------------------------
// WebObs wiki
//
mySettings = {
	nameSpace: 'wiki',
	previewParserPath:	'', // path to your Wiki parser
	onShiftEnter:		{keepDefault:false, replaceWith:'\n\n'},
	markupSet: [
		{name:'Heading 2', key:'2', openWith:'== ', closeWith:' ==', placeHolder:'Your title here...' },
		{name:'Heading 3', key:'3', openWith:'=== ', closeWith:' ===', placeHolder:'Your title here...' },
		{name:'Heading 4', key:'4', openWith:'==== ', closeWith:' ====', placeHolder:'Your title here...' },
		{separator:'---------------' },		
		{name:'Bold', key:'B', openWith:"**", closeWith:"**"}, 
		{name:'Italic', key:'I', openWith:"//", closeWith:"//"}, 
		{name:'Underline', key:'S', openWith:'__', closeWith:'__'}, 
		{separator:'---------------' },
		{name:'Bulleted list', openWith:'(!(- |!|-)!)'}, 
		{name:'Numeric list', openWith:'(!(# |!|#)!)'}, 
		{name:'Table', openWith:'||'}, 
		{separator:'---------------' },
		{name:'Picture', key:"P", openWith:'{{{[![img Url]!]}}}'}, 
	    {name:'Link', key:"L", replaceWith:'[[![linktext]!]]{[![url]!]}'},
		{name:'Node', key:'N', openWith:'{{', closeWith:'}}', placeHolder:'gridtype.gridname.nodename'},
		{separator:'---------------' },
		{name:'HRule',  openWith:"----"},
		{name:'Quotes',  openWith:'""', closeWith:'""', placeHolder:'Your quote here...' },
		{name:'Drawer',  openWith:'~~', closeWith:'~~', placeHolder:'Your drawer title:contents...' },
		//{separator:'---------------' },
		//{name:'Code', openWith:'(!(<source lang="[![Language:!:php]!]">|!|<pre>)!)', closeWith:'(!(</source>|!|</pre>)!)'}
		//{separator:'---------------' },
		//{name:'Preview', call:'preview', className:'preview'}
	]
}; 

