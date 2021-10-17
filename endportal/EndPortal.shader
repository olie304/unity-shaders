// Ported to HLSL by olie304 (https://github.com/olie304)

Shader "Custom/EndPortal"
{
	Properties
	{
		_EndSky("End Sky Texture", 2D) = "black" {}
		_EndPortal("End Portal Texture", 2D) = "black" {}
		_Scale("Texture Scale", Range(0.0,10.0)) = 4.0
		_HeightOffset("Height Offset", Range(-10.0,1.0)) = 0.75
		_Speed("Speed Multiplier", Range(0.0125,100.0)) = 1.0
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" }
		LOD 100
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD1;
				UNITY_FOG_COORDS(1)
			};

			sampler2D _EndSky;
			sampler2D _EndPortal;
			float _Scale;
			float _HeightOffset;
			float _RotationOffset;
			float _Speed;

			// These are pre-generated with the same algorithm and seed Minecraft uses.
			static const float randomMap[] = {0.09449595f,0.5119912f,0.4775676f,0.0021561384f,0.830713f,0.52125f,0.2421807f,0.827019f,0.60521126f,0.49845827f,0.8482403f,0.72256434f,0.70861703f,0.84773946f,0.3606466f,0.6288944f,0.32963306f,0.6073999f,0.81780994f,0.5439297f,0.99656105f,0.87238294f,0.8953165f,0.0017044544f,0.8615218f,0.51143605f,0.9519068f,0.6794915f,0.19169158f,0.68505853f,0.86813074f,0.30622542f,0.18865299f,0.2900399f,0.90332574f,0.65054363f,0.9805945f,0.057396412f,0.28817332f,0.036404908f,0.7766893f,0.6098513f,0.6186982f,0.76004106f,0.20826548f,0.042864203f,0.14446187f,0.9844728f};
			static uint randomIndex = 0;

			inline float GetNextFloat()
			{
				return randomMap[randomIndex++];
			}

			v2f vert(const appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				TANGENT_SPACE_ROTATION;
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
				//o.viewDir = mul(rotation, WorldSpaceViewDir(v.vertex));
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			float4 frag(const v2f i) : SV_Target
			{
				float4 color = float4(0,0,0,0);
				for (uint j = 0; j < 16; ++j)
				{
					float2 uv = i.uv;
					float adjDepth = j + 1;
					//float colorCoeff = 1.0F / ((16 - j) + 1.0F);  // Real Colors (Dark and boring)
					float colorCoeff = 2.0f / (18 - j);  // Better than real colors (Epic and based)

					uv += (i.viewDir.xy / i.viewDir.z) * -1.0f * ((16 - j) - (float)_HeightOffset);  // Transforms each layer in Tangent space for parallax effect
					
					uv.xy -= 0.5f;
					float s = sin(radians((adjDepth * adjDepth * 4321.0f + adjDepth * 9.0f) * 2.0f));
					float c = cos(radians((adjDepth * adjDepth * 4321.0f + adjDepth * 9.0f) * 2.0f));
					float2x2 rotationMatrix = float2x2(c, -s, s, c);
					rotationMatrix *= 0.5f;
					rotationMatrix += 0.5f;
					rotationMatrix = rotationMatrix * 2 - 1;
					uv.xy = mul(uv.xy, rotationMatrix);
					uv.xy += 0.5f;

					uv.xy *= (float)_Scale;
					uv.x -= 17.0f / adjDepth;
					uv.y -= (2.0f + adjDepth / 1.5f) * (_Time % (80.0f * (1.0f / (float)_Speed)) / (80.0f * (1.0f / (float)_Speed)));

					float4 tempCol = float4(0,0,0,0);
					if (j == 0)
					{
						colorCoeff = 0.15f;
						tempCol = tex2D(_EndSky, uv*0.125f);
					}
					if (j >= 1)
					{
						if (j == 1)
						{
							tempCol = tex2D(_EndPortal, uv*0.5f) * (1.0f - color.w);
						}
						else
						{
							tempCol = tex2D(_EndPortal, uv*0.0625f);
						}
					}
					tempCol.x *= (GetNextFloat() * 0.5f + 0.1f) * colorCoeff;
					tempCol.y *= (GetNextFloat() * 0.5f + 0.4f) * colorCoeff;
					tempCol.z *= (GetNextFloat() * 0.5f + 0.5f) * colorCoeff;
					color += tempCol;
				}
				UNITY_APPLY_FOG(i.fogCoord, color);
				return color;
			}
			ENDCG
		}
	}
}
