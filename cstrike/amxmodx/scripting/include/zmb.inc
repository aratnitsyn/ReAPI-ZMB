#if defined _zmb_included
	#endinput
#endif

#define _zmb_included

/**----------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/** [ `ZMB` ]
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#if defined _zmb_included
	
	#define SetBit(%0,%1)           ((%0) |= (1 << (%1 - 1)))
	#define ClearBit(%0,%1)         ((%0) &= ~(1 << (%1 - 1)))
	#define IsSetBit(%0,%1)         ((%0) & (1 << (%1 - 1)))
	#define InvertBit(%0,%1)        ((%0) ^= (1 << (%1 - 1)))
	#define IsNotSetBit(%0,%1)      (~(%0) & (1 << (%1 - 1)))

	#define IsPlayer(%0)            (%0 >= 1 && %0 <= g_iMaxPlayers)
	
	const MsgId_TextMsg             = 77;
	const MsgId_ReceiveW            = 129;
	const MsgId_SendAudio           = 100;
	const MsgId_ScreenFade          = 98;
	const MsgId_HideWeapon          = 94;

	enum Color	{
		COLOR_RED,
		COLOR_GREEN,
		COLOR_BLUE
	};
	
	/*
	*	...
	*
	*	@noreturn
	*/
	stock UTIL_ParseHEXColor(const szValue[])	{
		new iColor[Color];
		
		if(szValue[0] != '#' && strlen(szValue) != 7)
		{
			return iColor;
		}

		iColor[COLOR_RED] = UTIL_Parse16bit(szValue[1], szValue[2]);
		iColor[COLOR_GREEN] = UTIL_Parse16bit(szValue[3], szValue[4]);
		iColor[COLOR_BLUE] = UTIL_Parse16bit(szValue[5], szValue[6]);

		return iColor;
	}
	
	/*
	*	...
	*
	*	@noreturn
	*/
	stock UTIL_Parse16bit(const cSymbolA, const cSymbolB)	{
		return UTIL_ParseHex(cSymbolA) * 16 + UTIL_ParseHex(cSymbolB);
	}

	/*
	*	...
	*
	*	@noreturn
	*/
	stock UTIL_ParseHex(const cSymbol)	{
		if('0' <= cSymbol && cSymbol <= '9')
		{
			return cSymbol - '0';
		}
		
		if('a' <= cSymbol && cSymbol <= 'f')
		{
			return 10 + cSymbol - 'a';
		}
		
		if('A' <= cSymbol && cSymbol <= 'F')
		{
			return 10 + cSymbol - 'A';
		}

		return 0;
	}
	
#endif

/**----------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/** [ `AmxModX` ]
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#if defined _amxmodx_included
	
	/*
	*	Сложение двух векторов.
	*
	*	@param fVectorA			Вектор A.
	*	@param fVectorB			Вектор B.
	*	@param fOut				Вектор C [A + B].
	*
	*	@noreturn
	*/
	stock UTIL_VecAdd(const Float: fVectorA[3], const Float: fVectorB[3], Float: fOut[3])	{
		fOut[0] = fVectorA[0] + fVectorB[0];
		fOut[1] = fVectorA[1] + fVectorB[1];
		fOut[2] = fVectorA[2] + fVectorB[2];
	}
	
	/*
	*	Умножение вектора на число.
	*
	*	@param fVector			Вектор A.
	*	@param fScalar			Число.
	*	@param fOut				Вектор B [A * fScalar].
	*
	*
	*	@noreturn
	*/
	stock UTIL_VecMulScalar(const Float: fVector[3], const Float: fScalar, Float: fOut[3])	{
		fOut[0] = fVector[0] * fScalar;
		fOut[1] = fVector[1] * fScalar;
		fOut[2] = fVector[2] * fScalar;
	}
	
	/*
	*	Запись ошибок в файл.
	*
	*	@param szPlugin			Название плагина.
	*	@param szMessage		Текст ошибки.
	*
	*	@noreturn
	*/
	stock UTIL_SetFileState(const szPlugin[], const szMessage[], any:...)	{
		new szLog[256];
		vformat(szLog, charsmax(szLog), szMessage, 3);
		
		new szDate[20];
		get_time("error_%Y%m%d.log", szDate, charsmax(szDate));
		
		log_to_file(szDate, "[%s] %s", szPlugin, szLog);
	}
	
	/*
	*	Удаление кавычек и пробелов в слове.
	*
	*	@param szWord			Слово.
	*
	*	@noreturn
	*/
	stock UTIL_ConversionWord(szWord[])	{
		for(new iCount, iStrLen = strlen(szWord); iCount < iStrLen; iCount++)
		{
			if(szWord[iCount] == '"')
			{
				szWord[iCount] = ' ';
			}
		}

		trim(szWord);
	}
	
	/*
	*	Скрытие худа у игрока.
	*
	*	@param iIndex			Индекс игрока.
	*	@param iHideHud			Идетификатор худа.
	*
	*	@noreturn
	*/
	stock UTIL_SetPlayerHideHud(const iIndex, const iHideHud)	{
		message_begin(MSG_ONE, MsgId_HideWeapon, {0, 0, 0}, iIndex);
		{
			write_byte(iHideHud);
		}
		message_end();
	}
	
	/*
	*	Цвет экрана.
	*
	*	@param iIndex			Индекс игрока.
	*	@param iDuration		Продолжительность.
	*	@param iHoldTime		Время затухания.
	*	@param iFlags			Флаг ScreenFade.
	*	@param iRed				Значение красного цвета.
	*	@param iGreen			Значение зелённого цвета.
	*	@param iBlue			Значение голубого цвета.
	*	@param iAlpha			Насыщенность.
	*
	*	@noreturn
	*/
	stock UTIL_SetPlayerScreenFade(const iIndex, const iDuration, const iHoldTime, const iFlags, const iRed, const iGreen, const iBlue, const iAlpha)	{
		message_begin(MSG_ONE, MsgId_ScreenFade, {0, 0, 0}, iIndex);
		{
			write_short(iDuration);
			write_short(iHoldTime);
			write_short(iFlags);
			write_byte(iRed);
			write_byte(iGreen);
			write_byte(iBlue);
			write_byte(iAlpha);
		}
		message_end();
	}
	
	/*
	*	Установка освещённости на карте.
	*
	*	@param iIndex			Индекс игрока.
	*	@param szMapLightStyle	Индекс освещённости [от "a" до "z"]
	*
	*	@noreturn
	*/
	stock UTIL_SetPlayerMapLightStyle(const iIndex, const szMapLightStyle[])	{
		message_begin(MSG_ONE, SVC_LIGHTSTYLE, {0, 0, 0}, iIndex);
		{
			write_byte(0);
			write_string(szMapLightStyle);
		}
		message_end();
	}
	
	/*
	*	Установка погоды на карте.
	*
	*	@param iIndex			Индекс игрока [0 - всем игрокам].
	*	@param iWeather			Индекс погоды.
	*	       [0] - ничего;
	*	       [1] - дождь;
	*	       [2] - снег;
	*
	*	@noreturn
	*/
	stock UTIL_SetPlayerWeather(const iIndex, const iWeather)	{
		switch(iIndex)
		{
			case 0:
			{
				message_begin(MSG_ALL, MsgId_ReceiveW);
				{
					write_byte(iWeather);
				}
				message_end();
			}
			default:
			{
				message_begin(MSG_ONE, MsgId_ReceiveW, {0, 0, 0}, iIndex);
				{
					write_byte(iWeather);
				}
				message_end();
			}
		}
	}

#endif

/**----------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/** [ `ReAPI` ]
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#if defined _reapi_included

	/*
	*	Удаление оружия из определённого слота.
	*
	*	@param iIndex			Индекс игрока.
	*	@param iSlot			Индекс слота.
	*
	*	@noreturn
	*/
	stock UTIL_RemovePlayerSlotWeapon(const iIndex, const InventorySlotType: iSlot)	{
		new iItem = get_member(iIndex, m_rgpPlayerItems, iSlot), szWeaponClassName[20];

		while(iItem > 0)
		{
			get_entvar(iItem, var_classname, szWeaponClassName, charsmax(szWeaponClassName));

			rg_remove_item(iIndex, szWeaponClassName);

			iItem = get_member(iItem, m_pNext);
		}
	}
	
	/*
	*	Установка свечения объекту.
	*
	*	@param iIndex			Индекс объекта.
	*	@param iRenderFx		Тип.
	*	@param fColor[3]		Цвет.
	*	@param iRenderMode		Режим.
	*	@param iRenderAmt		Плотность.
	*
	*	@noreturn
	*/
	stock UTIL_SetEntityRendering(const iEntity, const iRenderFx, const Float: fColor[3], const iRenderMode, const iRenderAmt)	{
		set_entvar(iEntity, var_renderfx, iRenderFx);
		set_entvar(iEntity, var_renderamt, iRenderAmt);
		set_entvar(iEntity, var_rendermode, iRenderMode);
		
		set_entvar(iEntity, var_rendercolor, fColor);
	}

#endif

/**----------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/** [ `FakeMeta` ]
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#if defined _fakemeta_included

	/*
	*	...
	*
	*	@param iEntity			Индекс объекта.
	*	@param szClssName		Classname объекта.
	*	@param szKeyName		Название ключа.
	*	@param szValue			Значение ключа.
	*
	*	@return
	*/
	stock UTIL_SetKvd(const iEntity, const szClssName[], const szKeyName[], const szValue[])	{
		set_kvd(0, KV_ClassName, szClssName);
		set_kvd(0, KV_KeyName, szKeyName);
		set_kvd(0, KV_Value, szValue);
		set_kvd(0, KV_fHandled, 0);

		return dllfunc(DLLFunc_KeyValue, iEntity, 0);
	}

#endif